# frozen_string_literal: true

class TxOutset < ApplicationRecord
  belongs_to :block
  belongs_to :node

  def parent
    block.parent.tx_outsets.where(node: node).first
  end

  def as_json(options = nil)
    p = parent
    fields = %i[txouts total_amount created_at inflated]
    super({ only: fields }.merge(options || {})).merge({
                                                         height: block.height,
                                                         expected_increase: block.max_inflation / 100_000_000.0,
                                                         expected_supply: p.present? ? p.total_amount + (block.max_inflation / 100_000_000.0) : nil,
                                                         increase: p.present? ? total_amount - p.total_amount : nil
                                                       })
  end
end
