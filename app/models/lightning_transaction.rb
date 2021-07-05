# frozen_string_literal: true

require 'csv'

class LightningTransaction < ApplicationRecord
  PER_PAGE = Rails.env.production? ? 100 : 2

  enum type: { PenaltyTransaction: 0, MaybeUncoopTransaction: 1, SweepTransaction: 2 }

  after_commit :expire_cache

  belongs_to :block
  belongs_to :parent, class_name: 'LightningTransaction', optional: true
  belongs_to :opening_block, class_name: 'Block', optional: true
  has_one :child, class_name: 'LightningTransaction', foreign_key: 'parent_id'

  def as_json(options = nil)
    fields = %i[id tx_id amount opening_tx_id channel_is_public]
    super({ only: fields }.merge(options || {})).merge({
                                                         block: block,
                                                         channel_id_1ml: channel_id_1ml.present? ? channel_id_1ml.to_s : nil,
                                                         channel_age: self.PenaltyTransaction? && opening_block ? block.timestamp - opening_block.timestamp : nil
                                                       })
  end

  def get_opening_tx_id_and_block_hash!(close_tx)
    # Fetch all input transactions and return the first one that could be a channel
    # opening transaction.
    #
    # Previously we would check that all inputs to the closing transaction refer
    # to the same opening transaction id (but different outputs). But this isn't
    # always the case, e.g. 1c88ad14b349989a600745d47a743effa9385a1d738c5d755f1c74fe955a9a75
    # spends from two different opening(?) transactions.
    close_tx.in.each do |tx_in|
      # Must have a witness
      next if tx_in.script_witness.empty?

      opening_tx_id = close_tx.in.first.prev_out_hash.reverse.unpack1('H*')
      opening_tx_raw = Node.first_with_txindex(:btc).getrawtransaction(opening_tx_id, true)
      return opening_tx_id, opening_tx_raw['blockhash']
    end
    # Could not find an opening transaction
    throw "Unable to find opening transaction for closing transaction #{close_tx.hash}"
  end

  def find_parent!
    tx = Bitcoin::Protocol::Tx.new([raw_tx].pack('H*'))
    parent_tx_id = tx.in[input].prev_out_hash.reverse.unpack1('H*')
    parent_tx_vout = tx.in[input].prev_out_index
    LightningTransaction.where(tx_id: parent_tx_id).find_each do |candidate|
      update parent: candidate, parent_tx_vout: parent_tx_vout
      return parent
    end
    nil
  end

  def block_height
    block.try :height
  end

  def date
    Time.at(block.timestamp).to_datetime.iso8601
  end

  def parent_tx_id
    parent.try :tx_id
  end

  private

  def expire_cache
    Rails.cache.delete("#{self.class.name}.csv")
    Rails.cache.delete("#{self.class.name}.last_updated")
    Rails.cache.delete("#{self.class.name}.all_with_block")
    (1..(self.class.count / PER_PAGE + 1)).each do |page|
      Rails.cache.delete("#{self.class.name}.page_with_block_cached(#{page})")
    end
    Rails.cache.delete("#{self.class.name}.count")
  end

  class << self
    def to_csv
      attributes = %w[id block_height date tx_id input amount channel_is_public parent_tx_id]

      CSV.generate(headers: true) do |csv|
        csv << attributes

        eager_load(:block, :parent).order(height: :desc).each do |tx|
          csv << attributes.map { |attr| tx.send(attr) }
        end
      end
    end

    # Used once for migration
    def get_opening_blocks!
      PenaltyTransaction.all.find_each do |penalty|
        coin = penalty.block.coin.to_sym
        opening_tx = Node.first_with_txindex(coin).getrawtransaction(penalty.opening_tx_id, true)
        block = Block.find_by coin: coin, block_hash: opening_tx['blockhash']
        penalty.update opening_block: block
      end
    end

    def check!(options)
      throw 'Only BTC mainnet supported' unless options[:coin].nil? || options[:coin] == :btc
      throw 'Must specifiy :max' unless options.key?(:max)
      throw 'Parameter :max should be at least 1' if options[:max] < 1
      begin
        node = Node.first_with_txindex(:btc, :core)
      rescue BitcoinUtil::RPC::NoTxIndexError
        puts 'Unable to perform lightning checks, because no suitable node is available'
        return
      end

      blocks_to_check = []
      block = node.block
      while true
        if block.nil?
          missing_block = true
          break
        end
        break if block.checked_lightning

        # Don't perform lightning checks for more than 10 (default) blocks; it will take too long to catch up
        if blocks_to_check.count > options[:max]
          max_exceeded = true
          break
        end
        blocks_to_check.unshift(block)
        block = block.parent
      end

      if blocks_to_check.count.positive? && !Rails.env.test?
        puts "Scan blocks for relevant Lightning transactions using #{node.name_with_version}..."
      end

      blocks_to_check.each do |block|
        # libbitcoin doesn't return timestamps, so fetch those if needed
        if block.timestamp.nil?
          block_info = node.client.getblockheader(block.block_hash)
          block.update timestamp: block_info['time'], mediantime: block_info['mediantime']
        end

        begin
          retries ||= 0
          raw_block = node.getblock(block.block_hash, 0)
        rescue BitcoinUtil::RPC::PartialFileError
          if (retries += 1) < 2
            sleep 10 unless Rails.env.test?
            retry
          else
            raise
          end
        rescue BitcoinUtil::RPC::ConnectionError
          # The node probably crashed or temporarly ran out of RPC slots. Mark node
          # as unreachable and gracefull exit
          puts "Lost connection to #{node.name_with_version}. Try again later." unless Rails.env.test?
          node.update unreachable_since: Time.now
          return false
        end
        parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
        puts "Block #{block.height} (#{block.block_hash}, #{parsed_block.tx.count} txs)" unless Rails.env.test?
        MaybeUncoopTransaction.check!(node, block, parsed_block)
        PenaltyTransaction.check!(node, block, parsed_block)
        SweepTransaction.check!(node, block, parsed_block)
        block.update checked_lightning: true
      end

      raise 'Unable to perform lightning checks due to missing intermediate block' if missing_block

      if max_exceeded
        raise "More than #{options[:max]} blocks behind for lightning checks, please manually check blocks before #{blocks_to_check.first.height} (#{blocks_to_check.first.block_hash})"
      end

      true
    end

    def check_public_channels!
      LightningTransaction.where(channel_is_public: nil).find_each do |tx|
        uri = URI.parse('https://1ml.com/search')
        begin
          response = Net::HTTP.post_form(uri, { 'q' => tx.opening_tx_id })
          if response.code.to_i == 302 && response['location'] =~ %r{/channel/(\d+)}
            tx.update(channel_is_public: true, channel_id_1ml: Regexp.last_match(1).to_i)
          else
            tx.update channel_is_public: false
          end
        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
               Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
          puts "1ml search for #{tx.opening_tx_id} returned error #{e}, try again later" unless Rails.env.test?
          sleep 10
        end
      end
    end

    def last_updated_cached
      Rails.cache.fetch("#{name}.last_updated") { order(updated_at: :desc).first }
    end

    def all_with_block_cached
      Rails.cache.fetch("#{name}.all_with_block") { joins(:block).order(height: :desc).to_a }
    end

    def page_with_block_cached(page)
      Rails.cache.fetch("#{name}.page_with_block_cached(#{page})") do
        joins(:block).order(height: :desc).offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
      end
    end

    private

    def get_input_amount(node, tx, input)
      input_transaction = tx.inputs[input]
      tx_id = input_transaction.prev_out_hash.reverse.unpack1('H*')
      raw_tx = node.client.getrawtransaction(tx_id)
      parsed_tx = Bitcoin::Protocol::Tx.new([raw_tx].pack('H*'))
      parsed_tx.out[input_transaction.prev_out_index].value / 100_000_000.0
    end
  end
end
