class AddAmountToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :amount, :decimal, precision: 16, scale: 8

    Transaction.destroy_all
  end
end
