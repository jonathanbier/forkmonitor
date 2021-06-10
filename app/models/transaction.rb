# frozen_string_literal: true

class Transaction < ApplicationRecord
  belongs_to :block

  def as_json(options = nil)
    super({ only: %i[tx_id amount] }.merge(options || {}))
  end

  def spent_coins_map
    tx = Bitcoin::Protocol::Tx.new([raw].pack('H*'))
    map = {}
    tx.in.each do |input|
      parent_tx_id = input.prev_out_hash.reverse.unpack1('H*')
      parent_tx_vout = input.prev_out_index
      map["#{parent_tx_id}##{parent_tx_vout}"] = self
    end
    map
  end

  def outputs
    tx = Bitcoin::Protocol::Tx.new([raw].pack('H*'))
    tx.out
  end
end
