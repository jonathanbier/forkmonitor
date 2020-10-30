class Transaction < ApplicationRecord
  belongs_to :block

  def as_json(options = nil)
    super({ only: [:tx_id, :amount] }.merge(options || {}))
  end

  def spent_coins_map
    throw "raw transaction missing for #{ self.tx_id }" unless self.raw.present?

    tx = Bitcoin::Protocol::Tx.new([self.raw].pack('H*'))
    map = {}
    tx.in.each do |input|
      parent_tx_id = input.prev_out_hash.reverse.unpack("H*")[0]
      parent_tx_vout = input.prev_out_index
      map["#{ parent_tx_id }##{ parent_tx_vout }"] = self
    end
    return map
  end
end
