# frozen_string_literal: true

class AddParentTxVoutToLightningTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :lightning_transactions, :parent_tx_vout, :int
  end
end
