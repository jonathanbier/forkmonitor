class Block < ApplicationRecord
  def as_json(options = nil)
    super({ only: [:height, :timestamp] }.merge(options || {})).merge({hash: block_hash, work: log2_pow})
  end

  def log2_pow
    return nil if work.nil?
    Math.log2(work.to_i(16))
  end
end
