class InflatedBlock < ApplicationRecord
  belongs_to :block
  belongs_to :node

  def as_json(options = nil)
    super({ only: [:id, :max_inflation, :actual_inflation, :dismissed_at] }).merge({
      coin: block.coin.upcase,
      extra_inflation: actual_inflation - max_inflation,
      block: block,
      node: {
        id: node.id,
        name: node.name,
        name_with_version: node.name_with_version
      }
    })
  end

  def tx_outset
    TxOutset.find_by(block: self.block, node: self.node)
  end

  def self.check_inflation!(options)
    max = options[:max].present? ? options[:max] : 10
    max_exceeded = false
    comparison_block = nil

    Node.coin_by_version(options[:coin]).each do |node|
      next unless node.mirror_node? && node.core?
      puts "Check #{ node.coin } inflation for #{ node.name_with_version }..." unless Rails.env.test?
      throw "Node in Initial Blockchain Download" if node.ibd
      if node.restore_mirror == false
        puts "Node not reachable, skipping"
        next
      end

      begin
        # If anything goes wrong, re-enable the p2p networking and undo invalidateblock before throwing
        invalidated_block_hashes = []

        begin
          # Update mirror node tip and fetch most recent blocks if needed
          node.poll_mirror!
          node.reload # without this, ancestors of node.block_block are not updated
        rescue BitcoinClient::Error
          # Ignore failure
          puts "Unable to connect to mirror node #{ node.id } #{ node.name_with_version }, skipping inflation check."
          next
        end

        # Avoid expensive call if we already have this information for the most recent tip (of the mirror node):
        if TxOutset.find_by(block: node.mirror_block, node: node).present?
          puts "Already checked #{ node.name_with_version } for current mirror tip" unless Rails.env.test?
          next
        end

        puts "Stop p2p networking to prevent the chain from updating underneath us" unless Rails.env.test?
        node.mirror_client.setnetworkactive(false)

        # We want to call gettxoutsetinfo at every height since the last check.
        # Roll back the chain using invalidateblock (height + 1) if needed.
        blocks_to_check = [node.mirror_block]
        # Find previous block with txoutsetinfo
        comparison_block = node.mirror_block
        comparison_tx_outset = nil
        while true
          # Don't try to calculate inflation for more than 10 (default) blocks; it will take too long to catch up
          if node.mirror_block.height - comparison_block.height >= max
            max_exceeded = true
            break
          end
          comparison_block = comparison_block.parent
          throw "Unable to check inflation due to missing intermediate block" if comparison_block.nil?
          comparison_tx_outset = TxOutset.find_by(node: node, block: comparison_block)
          break if comparison_tx_outset.present?
          blocks_to_check.unshift(comparison_block)
        end

        blocks_to_check.each do |block|
          # Invalidate new blocks, including any forks we don't know of yet
          puts "Roll back the chain to #{ block.block_hash } (#{ block.height })..." unless Rails.env.test?
          tally = 0
          while(active_tip = node.get_mirror_active_tip; active_tip.present? && block.block_hash != active_tip["hash"])
            if tally > (Rails.env.test? ? 2 : 100)
              throw "Unable to roll active chaintip to #{ block.block_hash } (#{ block.height })"
            elsif tally > 0
              # Fetch blocks for any newly activated chaintips
              node.poll_mirror!
            end
            puts "Current tip #{ active_tip["hash"] } (#{ active_tip["height"] })" unless Rails.env.test?
            blocks_to_invalidate = []
            if block.height == active_tip["height"]
              # Invalidate tip to jump to another fork
              tip_block = Block.find_by(block_hash: active_tip["hash"])
              blocks_to_invalidate.append(tip_block)
            else
              block.children.each do |child_block| # Invalidate all child blocks we know of, if the node knows them
                begin
                  node.mirror_client.getblockheader(child_block.block_hash)
                rescue BitcoinClient::Error
                  puts "Skip invalidation of #{ child_block.block_hash } (#{ child_block.height }) because mirror node doesn't have it"
                  next
                end
                unless invalidated_block_hashes.include?(child_block.block_hash)
                  blocks_to_invalidate.append(child_block)
                end
              end
            end
            # Stop if there are no new blocks to invalidate
            if (blocks_to_invalidate.collect { |b| b.block_hash } - invalidated_block_hashes).empty?
                throw "Unable to roll active chaintip to #{ block.block_hash } (#{ block.height })"
            end
            blocks_to_invalidate.each do |block|
              invalidated_block_hashes.append(block.block_hash)
              puts "Invalidate block #{ block.block_hash } (#{ block.height })" unless Rails.env.test?
              node.mirror_client.invalidateblock(block.block_hash) # This is a blocking call
            end
            tally += 1
          end

          throw "No active tip left after rollback. Was expecting #{ block.block_hash } (#{ block.height })" unless active_tip.present?
          throw "Unexpected active tip hash #{ active_tip["hash"] } (#{ active_tip["height"] }) instead of #{ block.block_hash } (#{ block.height })" unless active_tip["hash"] == block.block_hash

          puts "Get the total UTXO balance at height #{ block.height }..." unless Rails.env.test?
          txoutsetinfo = node.mirror_client.gettxoutsetinfo

          unless invalidated_block_hashes.empty?
            puts "Restore chain to tip..." unless Rails.env.test?
            invalidated_block_hashes.each do |block_hash|
              node.mirror_client.reconsiderblock(block_hash) # This is a blocking call
            end
            invalidated_block_hashes = []
          end

          # Make sure we got the block we expected
          throw "TxOutset is not for block #{ block.block_hash }" unless txoutsetinfo["bestblock"] == block.block_hash

          tx_outset = TxOutset.create_with(txouts: txoutsetinfo["txouts"], total_amount: txoutsetinfo["total_amount"]).find_or_create_by(block: block, node: node)

          # Check that inflation does not exceed the maximum permitted miner award per block
          prev_tx_outset = TxOutset.find_by(node: node, block: block.parent)
          if prev_tx_outset.nil?
            puts "No previous TxOutset to compare against, skipping inflation check for height #{ block.height }..." unless Rails.env.test?
            next
          end

          inflation = tx_outset.total_amount - prev_tx_outset.total_amount

          if inflation > block.max_inflation / 100000000.0
            tx_outset.update inflated: true
            inflated_block = block.inflated_block || block.create_inflated_block(node: node, max_inflation: block.max_inflation  / 100000000.0, actual_inflation: inflation)
            if !inflated_block.notified_at
              User.all.each do |user|
                UserMailer.with(user: user, inflated_block: inflated_block).inflated_block_email.deliver
              end
              inflated_block.update notified_at: Time.now
              Subscription.blast("inflated-block-#{ inflated_block.id }",
                                 "#{ inflated_block.actual_inflation -  inflated_block.max_inflation } BTC inflation",
                                 "Unexpected #{ inflated_block.actual_inflation -  inflated_block.max_inflation } BTC extra inflation \
                                 at block height #{ inflated_block.block.height } according to #{ node.name_with_version }.",
              )
            end
          end
        end

      rescue
        puts "Something went wrong, restoring node before bailing out..."
        puts "Resume p2p networking..."
        node.mirror_client.setnetworkactive(true)
        # Have node return to tip
        invalidated_block_hashes.each do |block_hash|
          puts "Reconsider block #{ block_hash }"
          node.mirror_client.reconsiderblock(block_hash) # This is a blocking call
        end
        puts "Node restored"
        raise # continue throwing error
      end
      # Resume p2p networking
      node.mirror_client.setnetworkactive(true)
    end

    if max_exceeded
      raise "More than #{ max } blocks behind for inflation check, please manually check #{ comparison_block.height } (#{ comparison_block.block_hash }) and earlier"
    end
  end
end
