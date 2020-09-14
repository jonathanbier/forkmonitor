class Transaction < ApplicationRecord
  belongs_to :block

  def as_json(options = nil)
    super({ only: [:tx_id, :amount] }.merge(options || {}))
  end
end
