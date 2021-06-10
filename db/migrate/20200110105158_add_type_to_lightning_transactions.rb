# frozen_string_literal: true

class AddTypeToLightningTransactions < ActiveRecord::Migration[5.2]
  def up
    add_column :lightning_transactions, :type, :integer
    LightningTransaction.update_all type: :PenaltyTransaction
    change_column :lightning_transactions, :type, :integer, null: false
    add_index :lightning_transactions, :type
  end

  def down
    remove_column :lightning_transactions, :type
  end
end
