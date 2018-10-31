class Block < ApplicationRecord
  def as_json(options = nil)
    super({ only: [:height, :timestamp, :work] }.merge(options || {})).merge({hash: block_hash})
  end
end
