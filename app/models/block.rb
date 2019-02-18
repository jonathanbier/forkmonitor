class Block < ApplicationRecord
  has_many :children, class_name: 'Block', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Block', foreign_key: 'parent_id', optional: true
  has_many :invalid_blocks

  def as_json(options = nil)
    super({ only: [:height, :timestamp] }.merge(options || {})).merge({hash: block_hash, work: log2_pow})
  end

  def log2_pow
    return nil if work.nil?
    Math.log2(work.to_i(16))
  end
end
