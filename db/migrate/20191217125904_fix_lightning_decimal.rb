# frozen_string_literal: true

class FixLightningDecimal < ActiveRecord::Migration[5.2]
  def up
    LightningTransaction.where.not(amount: nil).each do |tx|
      tx.update amount: tx.amount / 100_000_000
    end
  end
end
