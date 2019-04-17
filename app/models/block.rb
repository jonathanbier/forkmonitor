class Block < ApplicationRecord
  has_many :children, class_name: 'Block', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Block', foreign_key: 'parent_id', optional: true
  has_many :invalid_blocks
  belongs_to :first_seen_by, class_name: 'Node', foreign_key: 'first_seen_by_id', optional: true

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
    node = Node.bitcoin_by_version.first
    throw "Node in Initial Blockchain Download" if node.ibd

    puts "Get the total UTXO balance at the tip..." unless Rails.env.test?
    # Make sure we have all blocks up to the tip.
    # TODO: Check that the previous snapshot is a block ancestor, otherwise delete it

    # TODO: Check that inflation does not exceed 12.5 BTC per block (abort this simlified check after halvening)

    # TODO: Process each block and calculate inflation; compare with snapshot.

    # TODO: Send alert if greater than allowed
  end
end
