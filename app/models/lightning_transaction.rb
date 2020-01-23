require 'csv'

class LightningTransaction < ApplicationRecord
  PER_PAGE = Rails.env.production? ? 100 : 2

  enum type: [:PenaltyTransaction, :MaybeUncoopTransaction, :SweepTransaction]

  after_commit :expire_cache

  belongs_to :block
  belongs_to :parent, class_name: 'LightningTransaction', foreign_key: 'parent_id', optional: true
  has_one :child, class_name: 'LightningTransaction', foreign_key: 'parent_id'

  def as_json(options = nil)
    fields = [:id, :tx_id, :amount, :opening_tx_id, :channel_is_public]
    super({ only: fields }.merge(options || {})).merge({
      block: block,
      channel_id_1ml: channel_id_1ml.present? ? channel_id_1ml.to_s : nil
    })
  end

  def get_opening_tx_id!(close_tx)
    prev_out_hash = nil
    close_tx.in.each do |tx_in|
      if prev_out_hash.present? && tx_in.prev_out_hash != prev_out_hash
        throw "Unexpected reference to multiple transactions for closing transaction #{ self.tx_id }"
      end
      prev_out_hash = tx_in.prev_out_hash
    end
    opening_tx_id = close_tx.in.first.prev_out_hash.reverse.unpack("H*")[0]
    # Sanity check, raw transction is unused:
    opening_tx_raw = Node.first_with_txindex(:btc).getrawtransaction(opening_tx_id)
    return opening_tx_id
  end

  def find_parent!
    tx = Bitcoin::Protocol::Tx.new([self.raw_tx].pack('H*'))
    parent_tx_id = tx.in[self.input].prev_out_hash.reverse.unpack("H*")[0]
    parent_tx_vout = tx.in[self.input].prev_out_index
    LightningTransaction.where(tx_id: parent_tx_id).each do |candidate|
      self.update parent: candidate, parent_tx_vout: parent_tx_vout
      return parent
    end
    return nil
  end

  def self.check!(options)
    throw "Only BTC mainnet supported" unless options[:coin].nil? || options[:coin] == :btc
    throw "Must specifiy :max" unless options[:max].present?
    throw "Parameter :max should be at least 1" if options[:max] < 1
    node = Node.first_with_txindex(:btc, :core)

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

    if blocks_to_check.count > 0 and !Rails.env.test?
      puts "Scan blocks for relevant Lightning transactions using #{ node.name_with_version }..."
    end

    blocks_to_check.each do |block|
      # libbitcoin doesn't return timestamps, so fetch those if needed
      if block.timestamp.nil?
        block_info = node.client.getblockheader(block.block_hash)
        block.update timestamp: block_info["time"], mediantime: block_info["mediantime"]
      end

      raw_block = node.client.getblock(block.block_hash, 0)
      parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      puts "Block #{ block.height } (#{ block.block_hash }, #{ parsed_block.tx.count } txs)" unless Rails.env.test?
      MaybeUncoopTransaction.check!(node, block, parsed_block)
      PenaltyTransaction.check!(node, block, parsed_block)
      SweepTransaction.check!(node, block, parsed_block)
      block.update checked_lightning: true
    end

    if missing_block
      raise "Unable to perform lightning checks due to missing intermediate block"
    end

    if max_exceeded
      raise "More than #{ options[:max] } blocks behind for lightning checks, please manually check blocks before #{ blocks_to_check.first.height } (#{ blocks_to_check.first.block_hash })"
    end
  end

  def self.check_public_channels!
    LightningTransaction.where(channel_is_public: nil).each do |tx|
      uri = URI.parse("https://1ml.com/search")
      begin
        response = Net::HTTP.post_form(uri, {"q" => tx.opening_tx_id})
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
        Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        puts "1ml search for #{ tx.opening_tx_id } returned error #{ e }, try again later"
        sleep 10
      end
      if response.code.to_i == 302 && response["location"] =~ /\/channel\/(\d+)/
         tx.update(channel_is_public: true, channel_id_1ml: $1.to_i)
      else
        tx.update channel_is_public: false
      end
    end
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

  def self.to_csv
    attributes = %w{id block_height date tx_id input amount channel_is_public parent_tx_id }

    CSV.generate(headers: true) do |csv|
      csv << attributes

      all.each do |tx|
        csv << attributes.map{ |attr| tx.send(attr) }
      end
    end
  end

  private

  def self.get_input_amount(node, tx, input)
    input_transaction = tx.inputs[input]
    tx_id = input_transaction.prev_out_hash.reverse.unpack('H*')[0]
    raw_tx = node.client.getrawtransaction(tx_id)
    parsed_tx = Bitcoin::Protocol::Tx.new([raw_tx].pack('H*'))
    parsed_tx.out[input_transaction.prev_out_index].value / 100000000.0
  end

  def self.last_updated_cached
    Rails.cache.fetch("#{self.name}.last_updated") { order(updated_at: :desc).first }
  end

  def self.all_with_block_cached
    Rails.cache.fetch("#{self.name}.all_with_block") { joins(:block).order(height: :desc).to_a }
  end

  def self.page_with_block_cached(page)
    Rails.cache.fetch("#{self.name}.page_with_block_cached(#{page})") {
      joins(:block).order(height: :desc).offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    }
  end

  def expire_cache
    Rails.cache.delete("#{self.class.name}.csv")
    Rails.cache.delete("#{self.class.name}.last_updated")
    Rails.cache.delete("#{self.class.name}.all_with_block")
    for page in 1..(self.class.count / PER_PAGE + 1) do
      Rails.cache.delete("#{self.class.name}.page_with_block_cached(#{page})")
    end
    Rails.cache.delete("#{self.class.name}.count")
  end

end
