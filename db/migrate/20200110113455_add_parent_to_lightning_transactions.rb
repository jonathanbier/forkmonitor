# frozen_string_literal: true

class AddParentToLightningTransactions < ActiveRecord::Migration[5.2]
  def change
    add_reference :lightning_transactions, :parent, index: true
  end
end
