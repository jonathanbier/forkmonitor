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
    max = options.key?(:max) ? options[:max] : 10
    throw "Missing :coin argument" unless options.key?(:coin)
    throw "Invalid :coin argument #{ options[:coin] }" unless Node::SUPPORTED_COINS.include?(options[:coin])

    threads = []

    Rails.logger.info "Check #{ options[:coin] } inflation for #{ Node.coin_by_version(options[:coin]).count } nodes..."

    Node.coin_by_version(options[:coin]).each do |node|
      max_exceeded = false
      comparison_block = nil

      next unless node.mirror_node? && node.core?
      next unless node.mirror_rest_until.nil? || node.mirror_rest_until < Time.now

      # Check mirror node again if we marked it as unreachable more than 10 minutes ago
      if !node.mirror_unreachable_since.nil?
        next unless node.last_polled_mirror_at < 10.minutes.ago
        begin
          node.mirror_client.getblockchaininfo
          node.update mirror_unreachable_since: nil
          next
        rescue BitcoinClient::ConnectionError
          node.update last_polled_mirror_at: Time.now
        end
      end

      Rails.logger.info "Check #{ node.coin } inflation for #{ node.name_with_version }..."
      throw "Node in Initial Blockchain Download" if node.ibd
      if node.restore_mirror == false # false: unable to connect, nil: no mirror block
        Rails.logger.error "Unable to connect to mirror node #{ node.id } #{ node.name_with_version }"
        next
      end

      threads << Thread.new {
        begin
          # If anything goes wrong, re-enable the p2p networking and undo invalidateblock before throwing
          invalidated_block_hashes = []

          # Take a break if main node doesn't have a new block
          if TxOutset.find_by(block: node.block, node: node).present?
            sleep 5 unless Rails.env.test?
            Thread.exit
          end

          begin
            # Update mirror node tip and fetch most recent blocks if needed
            node.poll_mirror!
            node.reload # without this, ancestors of node.block_block are not updated
          rescue Node::ConnectionError
            Rails.logger.error "Unable to connect to mirror node #{ node.id } #{ node.name_with_version }, skipping inflation check."
            node.update mirror_unreachable_since: Time.now, last_polled_mirror_at: Time.now
            Thread.exit
          end

          # Skip if mirror node isn't synced
          Thread.exit if node.mirror_block.nil?

          # Avoid expensive call if we already have this information for the most recent tip (of the mirror node):
          if TxOutset.find_by(block: node.mirror_block, node: node).present?
            Rails.logger.debug "Already checked #{ node.name_with_version } for current mirror tip"
            Thread.exit
          end

          Rails.logger.debug "Stop p2p networking to prevent the chain from updating underneath us"
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
            throw "Unable to check inflation due to missing intermediate block on #{ node.name_with_version }" if comparison_block.nil?
            comparison_tx_outset = TxOutset.find_by(node: node, block: comparison_block)
            break if comparison_tx_outset.present?
            blocks_to_check.unshift(comparison_block)
          end

          blocks_to_check.each do |block|
            # Invalidate new blocks, including any forks we don't know of yet
            Rails.logger.debug "Roll back the chain to #{ block.block_hash } (#{ block.height }) on #{ node.name_with_version }..."
            tally = 0
            while(active_tip = node.get_mirror_active_tip; active_tip.present? && block.block_hash != active_tip["hash"])
              if tally > (Rails.env.test? ? 2 : 100)
                throw_unable_to_roll_back!(node, block)
              elsif tally > 0
                Rails.logger.debug "Fetch blocks for any newly activated chaintips on #{ node.name_with_version }..."
                node.poll_mirror!
                block.reload
              end
              Rails.logger.debug "Current tip #{ active_tip["hash"] } (#{ active_tip["height"] }) on #{ node.name_with_version }"
              blocks_to_invalidate = []
              active_tip_block = Block.find_by!(block_hash: active_tip["hash"])
              if block.height == active_tip["height"]
                Rails.logger.debug "Invalidate tip to jump to another fork"
                blocks_to_invalidate.append(active_tip_block)
              else
                Rails.logger.debug "Check if active chaintip descends from target block, otherwise invalidate the active chain..."
                if !block.descendants.include? active_tip_block
                  blocks_to_invalidate.append(active_tip_block.branch_start(block))
                end
                # Invalidate all child blocks we know of, if the node knows them
                block.children.each do |child_block|
                  begin
                    node.mirror_client.getblockheader(child_block.block_hash)
                  rescue BitcoinClient::Error
                    Rails.logger.error "Skip invalidation of #{ child_block.block_hash } (#{ child_block.height }) on #{ node.name_with_version } because mirror node doesn't have it"
                    next
                  end
                  unless invalidated_block_hashes.include?(child_block.block_hash)
                    blocks_to_invalidate.append(child_block)
                  end
                end
              end
              # Stop if there are no new blocks to invalidate
              if (blocks_to_invalidate.collect { |b| b.block_hash } - invalidated_block_hashes).empty?
                Rails.logger.error "Nothing to invalidate on #{ node.name_with_version }"
                throw_unable_to_roll_back!(node, block, blocks_to_invalidate, invalidated_block_hashes)
              end
              blocks_to_invalidate.each do |block|
                invalidated_block_hashes.append(block.block_hash)
                Rails.logger.debug "Invalidate block #{ block.block_hash } (#{ block.height }) on #{ node.name_with_version }"
                node.mirror_client.invalidateblock(block.block_hash) # This is a blocking call
              end
              tally += 1
              # Give node some time to update its internals. There were occasional
              # failures where the gettxoutsetinfo below would be applied to the
              # child block, despite checks against that.
              sleep 3
            end

            throw "No active tip left after rollback on #{ node.name_with_version }. Was expecting #{ block.block_hash } (#{ block.height })" unless active_tip.present?
            throw "Unexpected active tip hash #{ active_tip["hash"] } (#{ active_tip["height"] }) instead of #{ block.block_hash } (#{ block.height }) on #{ node.name_with_version }" unless active_tip["hash"] == block.block_hash

            Rails.logger.debug "Get the total UTXO balance at height #{ block.height } on #{ node.name_with_version }..."
            txoutsetinfo = node.mirror_client.gettxoutsetinfo

            unless invalidated_block_hashes.empty?
              Rails.logger.debug "Restore chain to tip on #{ node.name_with_version }..."
              invalidated_block_hashes.each do |block_hash|
                Rails.logger.debug "Reconsider block #{ block_hash } (#{ block.height }) on #{ node.name_with_version }"
                node.mirror_client.reconsiderblock(block_hash) # This is a blocking call
                sleep 1 # But wait anyway
              end
              invalidated_block_hashes = []
            end

            # Make sure we got the block we expected
            throw "TxOutset #{ txoutsetinfo["bestblock"] } is not for block #{ block.block_hash }" unless txoutsetinfo["bestblock"] == block.block_hash

            tx_outset = TxOutset.create_with(txouts: txoutsetinfo["txouts"], total_amount: txoutsetinfo["total_amount"]).find_or_create_by(block: block, node: node)

            # Update websockets
            InflationChannel.broadcast_to(node, tx_outset)

            # Check that inflation does not exceed the maximum permitted miner award per block
            prev_tx_outset = TxOutset.find_by(node: node, block: block.parent)
            if prev_tx_outset.nil?
              Rails.logger.error "No previous TxOutset to compare against, skipping inflation check for height #{ block.height }..."
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
          Rails.logger.error "Something went wrong, restoring node before bailing out..."
          Rails.logger.debug "Resume p2p networking..."
          node.mirror_client.setnetworkactive(true)
          # Have node return to tip
          invalidated_block_hashes.each do |block_hash|
            Rails.logger.debug "Reconsider block #{ block_hash }"
            node.mirror_client.reconsiderblock(block_hash) # This is a blocking call
            sleep 1 # But wait anyway
          end
          Rails.logger.debug "Node restored"
          # Give node some time to catch up:
          node.update mirror_rest_until: 60.seconds.from_now
          raise # continue throwing error
        end
        Rails.logger.debug "Resume p2p networking..."
        # Resume p2p networking
        node.mirror_client.setnetworkactive(true)
        # Leave node alone for a bit:
        node.update mirror_rest_until: 60.seconds.from_now

        if max_exceeded
          message = "More than #{ max } blocks behind for inflation check, please manually check #{ comparison_block.height } (#{ comparison_block.block_hash }) and earlier"
          if options[:coin] == :tbtc # Don't send error emails for testnet
            Rails.logger.error message
          else
            raise message
          end
        end
      } # end thread
    end

    threads.each(&:join)
  end

  def self.throw_unable_to_roll_back!(node, block, blocks_to_invalidate = nil, invalidated_block_hashes = nil)
    error = "Unable to roll active #{ block.coin.upcase } chaintip to #{ block.block_hash } (#{ block.height }) on node #{ node.id } #{ node.name_with_version }"
    error += "\nChaintips: #{ node.mirror_client.getchaintips.filter{|t| t["height"] > block.height - 100 }.collect { |t| "#{ t["hash"] } (#{ t["height"] })=#{ t["status"] }" }.join(", ") }"
    if !invalidated_block_hashes.nil?
      error += "\nInvalidated blocks: #{ invalidated_block_hashes.collect { |b| "#{ b.block_hash } (#{ b.height })" }.join(", ")}"
    end
    if !blocks_to_invalidate.nil?
      error += "\nBlocks to invalidate: #{ blocks_to_invalidate.collect { |b| "#{ b.block_hash } (#{ b.height })" }.join(", ")}"
    end
    throw error
  end
end
