class LightningTransaction < ApplicationRecord
  enum type: [:PenaltyTransaction]

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

  def self.check!(options)
    throw "Only BTC mainnet supported" unless options[:coin].nil? || options[:coin] == :btc
    throw "Must specifiy :max" unless options[:max].present?
    throw "Parameter :max should be at least 1" if options[:max] < 1
    node = Node.bitcoin_core_by_version.first

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
      raw_block = node.client.getblock(block.block_hash, 0)
      parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      puts "Block #{ block.height } (#{ block.block_hash }, #{ parsed_block.tx.count } txs)" unless Rails.env.test?
      PenaltyTransaction.check!(block, parsed_block)
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

  private

  def self.last_updated_cached
    Rails.cache.fetch('LightningTransaction.last_updated') { order(updated_at: :desc).first }
  end

  def self.all_with_block_cached
    Rails.cache.fetch('LightningTransaction.all_with_block') { joins(:block).order(height: :desc).to_a }
  end

  def expire_cache
    Rails.cache.delete('LightningTransaction.last_updated')
    Rails.cache.delete('LightningTransaction.all_with_block')
    Rails.cache.delete('api/v1/ln_penalties.json')
  end

end
