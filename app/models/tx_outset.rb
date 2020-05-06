class TxOutset < ApplicationRecord
  belongs_to :block
  belongs_to :node

  def parent
    block.parent.tx_outsets.where(node: node).first
  end

  def as_json(options = nil)
    fields = [:txouts, :total_amount, :created_at, :inflated]
    super({ only: fields }.merge(options || {})).merge({
      expected_increase: block.max_inflation / 100000000.0,
      expected_supply: parent.present? ? parent.total_amount + (block.max_inflation / 100000000.0) : nil,
      increase: parent.present? ? total_amount - parent.total_amount : nil
    })
  end

end
