# frozen_string_literal: true

class InflatedBlock < ApplicationRecord
  belongs_to :block
  belongs_to :node

  class Error < StandardError; end

  class TooFarBehindError < Error; end

  def as_json(_options = nil)
    super({ only: %i[id max_inflation actual_inflation dismissed_at] }).merge({
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
    TxOutset.find_by(block: block, node: node)
  end

  class << self
    def check_inflation!(options)
      max = options.key?(:max) ? options[:max] : 10
      throw 'Missing :coin argument' unless options.key?(:coin)
      throw "Invalid :coin argument #{options[:coin]}" unless Rails.configuration.supported_coins.include?(options[:coin])

      threads = []
      nodes = Node.with_mirror(options[:coin])
      Rails.logger.info "Check #{options[:coin].to_s.upcase} inflation for #{nodes.count} nodes..."
      throw "Increase RAILS_MAX_THREADS to match #{nodes.count} #{options[:coin]} mirror nodes." if nodes.count > (ENV['RAILS_MAX_THREADS'] || '5').to_i

      nodes.each do |node|
        max_exceeded = false

        next unless node.mirror_rest_until.nil? || node.mirror_rest_until < Time.zone.now

        # Check mirror node again if we marked it as unreachable more than 10 minutes ago
        unless node.mirror_unreachable_since.nil?
          next unless node.last_polled_mirror_at < 10.minutes.ago

          begin
            node.mirror_client.getblockchaininfo
            node.update mirror_unreachable_since: nil
            next
          rescue BitcoinUtil::RPC::ConnectionError
            node.update last_polled_mirror_at: Time.zone.now
          end
        end

        Rails.logger.info "Check #{node.coin.to_s.upcase} inflation for #{node.name_with_version}..."
        if node.ibd
          Rails.logger.info 'Node in Initial Blockchain Download'
          next
        end
        if node.restore_mirror == false # false: unable to connect, nil: no mirror block
          Rails.logger.error "Unable to connect to mirror node #{node.id} #{node.name_with_version}"
          next
        end

        Thread.report_on_exception = false if Rails.env.test?
        threads << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            check_inflation_for_node!(node, max, max_exceeded)
          end
        end
      end

      threads.each(&:join)
    end

    # Presumed to run inside a thread
    # max_exceeded is modified by this method
    def check_inflation_for_node!(node, max, max_exceeded)
      comparison_block = nil

      # catch errors
      begin
        # If anything goes wrong, re-enable the p2p networking and undo invalidateblock before throwing

        # Take a break if main node doesn't have a new block
        if TxOutset.find_by(block: node.block, node: node).present?
          sleep 5 unless Rails.env.test?
          Thread.exit
        end

        begin
          # Update mirror node tip and fetch most recent blocks if needed
          node.poll_mirror!
          node.reload # without this, ancestors of node.block_block are not updated
        rescue BitcoinUtil::RPC::ConnectionError
          Rails.logger.error "Unable to connect to mirror node #{node.id} #{node.name_with_version}, skipping inflation check."
          node.update mirror_unreachable_since: Time.zone.now, last_polled_mirror_at: Time.zone.now
          Thread.exit
        end

        # Skip if mirror node isn't synced
        Thread.exit if node.mirror_block.nil?

        # Avoid expensive call if we already have this information for the most recent tip (of the mirror node):
        if TxOutset.find_by(block: node.mirror_block, node: node).present?
          Rails.logger.info "Already checked #{node.name_with_version} for current mirror tip"
          Thread.exit
        end

        Rails.logger.info 'Stop p2p networking to prevent the chain from updating underneath us'
        node.mirror_client.setnetworkactive(false)

        # We want to call gettxoutsetinfo at every height since the last check.
        # Roll back the chain using invalidateblock (height + 1) if needed.
        blocks_to_check = [node.mirror_block]
        # Find previous block with txoutsetinfo
        comparison_block = node.mirror_block
        comparison_tx_outset = nil
        loop do
          # Don't try to calculate inflation for more than 10 (default) blocks; it will take too long to catch up
          if node.mirror_block.height - comparison_block.height >= max
            max_exceeded = true
            break
          end
          comparison_block = comparison_block.parent
          throw "Unable to check inflation due to missing intermediate block on #{node.name_with_version}" if comparison_block.nil?
          comparison_tx_outset = TxOutset.find_by(node: node, block: comparison_block)
          break if comparison_tx_outset.present?

          blocks_to_check.unshift(comparison_block)
        end

        blocks_to_check.each do |block|
          block.make_active_on_mirror!(node)

          Rails.logger.info "Get the total UTXO balance at height #{block.height} on #{node.name_with_version}..."
          txoutsetinfo = node.mirror_client.gettxoutsetinfo

          block.undo_rollback!(node)

          # Make sure we got the block we expected
          throw "TxOutset #{txoutsetinfo['bestblock']} is not for block #{block.block_hash}" unless txoutsetinfo['bestblock'] == block.block_hash

          tx_outset = TxOutset.create_with(txouts: txoutsetinfo['txouts'], total_amount: txoutsetinfo['total_amount']).find_or_create_by(
            block: block, node: node
          )

          # Update websockets
          InflationChannel.broadcast_to(node, tx_outset)

          # Check that inflation does not exceed the maximum permitted miner award per block
          prev_tx_outset = TxOutset.find_by(node: node, block: block.parent)
          if prev_tx_outset.nil?
            Rails.logger.error "No previous TxOutset to compare against, skipping inflation check for height #{block.height}..." unless Rails.env.test?
            next
          end

          inflation = tx_outset.total_amount - prev_tx_outset.total_amount

          next unless inflation > block.max_inflation / 100_000_000.0

          tx_outset.update inflated: true
          inflated_block = block.inflated_block || block.create_inflated_block(node: node,
                                                                               max_inflation: block.max_inflation / 100_000_000.0, actual_inflation: inflation)
          next if inflated_block.notified_at

          User.all.find_each do |user|
            UserMailer.with(user: user, inflated_block: inflated_block).inflated_block_email.deliver
          end
          inflated_block.update notified_at: Time.zone.now
          Subscription.blast("inflated-block-#{inflated_block.id}",
                             "#{inflated_block.actual_inflation - inflated_block.max_inflation} BTC inflation",
                             "Unexpected #{inflated_block.actual_inflation - inflated_block.max_inflation} BTC extra inflation \
                             at block height #{inflated_block.block.height} according to #{node.name_with_version}.")
        end
      rescue StandardError => e
        Rails.logger.error "Rescued: #{e.inspect}"
        Rails.logger.error 'Restoring node before bailing out...'
        Rails.logger.info 'Resume p2p networking...'
        node.mirror_client.setnetworkactive(true)
        # Have node return to tip, by reconsidering all invalid chaintips
        node.mirror_client.getchaintips.filter { |tip| tip['status'] == 'invalid' }.each do |tip|
          Rails.logger.info "Reconsider block #{tip['hash']}"
          node.mirror_client.reconsiderblock(tip['hash']) # This is a blocking call
          sleep 1 # But wait anyway
        end
        Rails.logger.info 'Node restored'
        # Give node some time to catch up:
        node.update mirror_rest_until: 60.seconds.from_now
        raise # continue throwing error
      end
      Rails.logger.info 'Resume p2p networking...'
      # Resume p2p networking
      node.mirror_client.setnetworkactive(true)
      # Leave node alone for a bit:
      node.update mirror_rest_until: 60.seconds.from_now

      if max_exceeded
        message = "More than #{max} blocks behind for inflation check, please manually check #{comparison_block.height} (#{comparison_block.block_hash}) and earlier"
        if node.tbtc? # Don't send error emails for testnet
          Rails.logger.error message
        else
          raise TooFarBehindError, message
        end
      end
    end
  end
end
