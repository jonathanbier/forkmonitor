class FixLightningDecimal < ActiveRecord::Migration[5.2]
  def up
    LightningTransaction.all.each do |tx|
      tx.update amount: tx.amount / 100000000
    end
  end
end
