class MakeTransactionAmountMandatory < ActiveRecord::Migration[5.2]
  def up
    Transaction.delete_all
    change_column :transactions, :amount, :decimal, precision: 16, scale: 8, null: false
  end
end
