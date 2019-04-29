class Block < ApplicationRecord
  has_many :children, class_name: 'Block', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Block', foreign_key: 'parent_id', optional: true
  has_many :invalid_blocks
  belongs_to :first_seen_by, class_name: 'Node', foreign_key: 'first_seen_by_id', optional: true
  enum coin: [:btc, :bch, :bsv]

  def as_json(options = nil)
    super({ only: [:height, :timestamp] }.merge(options || {})).merge({
      id: id,
      hash: block_hash,
      timestamp: timestamp,
      work: log2_pow,
      first_seen_by: first_seen_by ? {
        id: first_seen_by.id,
        name: first_seen_by.name,
        version: first_seen_by.version
      } : nil})
  end

  def log2_pow
    return nil if work.nil?
    Math.log2(work.to_i(16))
  end

  def self.check_inflation!
    # Use the latest node for this check
    node = Node.bitcoin_core_by_version.first
    throw "Node in Initial Blockchain Download" if node.ibd

    puts "Get the total UTXO balance at the tip..." unless Rails.env.test?
    txoutsetinfo = node.client.gettxoutsetinfo

    # Make sure we have all blocks up to the tip.
    block = Block.find_by(block_hash: txoutsetinfo["hash"])
    if block.nil?
      puts "Fetch recent blocks..." unless Rails.env.test?
      node.poll!
      block = node.block
      if block.block_hash != txoutsetinfo["bestblock"]
        throw "Latest block #{ txoutsetinfo["bestblock"] } at height #{ txoutsetinfo["height"] } missing in blocks database"
      end
    end

    outset = TxOutset.create_with(txouts: txoutsetinfo["txouts"], total_amount: txoutsetinfo["total_amount"]).find_or_create_by(block: block)

    # TODO: Check that the previous snapshot is a block ancestor, otherwise delete it

    # TODO: Check that inflation does not exceed 12.5 BTC per block (abort this simlified check after halvening)

    # TODO: Process each block and calculate inflation; compare with snapshot.

    # TODO: Send alert if greater than allowed
  end
end
