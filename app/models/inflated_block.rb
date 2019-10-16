class InflatedBlock < ApplicationRecord
  belongs_to :block
  belongs_to :node
  belongs_to :comparison_block, class_name: 'Block'
  
  def as_json(options = nil)
    super({ only: [:id, :max_inflation, :actual_inflation, :dismissed_at] }).merge({
      coin: block.coin.upcase,
      extra_inflation: actual_inflation - max_inflation,
      block: block, 
      comparison_block: comparison_block,
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
  
  def self.check_inflation!(coin)
    Node.where(coin: coin.to_s.upcase).each do |node|
      next unless node.mirror_node? && node.core?
      puts "Check #{ node.coin } inflation for #{ node.name_with_version }..." unless Rails.env.test?
      throw "Node in Initial Blockchain Download" if node.ibd
      
      puts "Restore mirror node to normal state if needed..." unless Rails.env.test?
      node.restore_mirror

      begin
        # If anything goes wrong, re-enable the p2p networking and undo invalidateblock before throwing
        invalidated_block_hashes = []

        begin
          # Update mirror node tip and fetch most recent blocks if needed
          node.poll_mirror!
          node.reload # without this, ancestors of node.block_block are not updated
        rescue Bitcoiner::Client::JSONRPCError
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
          comparison_block = comparison_block.parent
          if comparison_block.nil?
            puts "Unable to check inflation due to missing intermediate block" unless Rails.env.test?
            break
          end
          comparison_tx_outset = TxOutset.find_by(node: node, block: comparison_block)
          break if comparison_tx_outset.present?
          # Don't try to calculate inflation for more than 10 blocks; it will take too long to catch up
          break if node.mirror_block.height - comparison_block.height > 10
          blocks_to_check.unshift(comparison_block)
        end
                
        blocks_to_check.each do |block|          
          if block.height != node.mirror_block.height
            puts "Roll back the chain to #{ block.height }..." unless Rails.env.test?
            block.children.each do |child_block|
              invalidated_block_hashes.append(child_block.block_hash)
              node.mirror_client.invalidateblock(child_block.block_hash) # This is a blocking call
            end
          end

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
            inflated_block = block.inflated_block || block.create_inflated_block(node: node,comparison_block: comparison_block, max_inflation: block.max_inflation  / 100000000.0, actual_inflation: inflation)
            if !inflated_block.notified_at
              User.all.each do |user|
                UserMailer.with(user: user, inflated_block: inflated_block).inflated_block_email.deliver
              end
              inflated_block.update notified_at: Time.now
              Subscription.blast("inflated-block-#{ inflated_block.id }",
                                 "#{ inflated_block.actual_inflation -  inflated_block.max_inflation } BTC inflation",
                                 "Unexpected #{ inflated_block.actual_inflation -  inflated_block.max_inflation } BTC extra inflation \
                                 between block height #{ inflated_block.comparison_block.height } and #{ inflated_block.block.height } according to #{ node.name_with_version }.",
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
  end
end
