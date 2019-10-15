class TxOutset < ApplicationRecord
  belongs_to :block
  belongs_to :node
  
  def as_json(options = nil)
    fields = [:txouts, :total_amount, :created_at, :inflated]
    super({ only: fields }.merge(options || {}))
  end

end
