# frozen_string_literal: true

class AddInputToLightningTransactions < ActiveRecord::Migration[5.2]
  def up
    add_column :lightning_transactions, :input, :integer
    LightningTransaction.update_all input: 0
    change_column :lightning_transactions, :input, :integer, null: false
  end
end
