class Block < ApplicationRecord
  has_many :children, class_name: 'Block', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Block', foreign_key: 'parent_id', optional: true
  has_many :invalid_blocks
  belongs_to :first_seen_by, class_name: 'Node', foreign_key: 'first_seen_by_id', optional: true

  def as_json(options = nil)
    super({ only: [:height, :timestamp] }.merge(options || {})).merge({
      hash: block_hash,
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
end
