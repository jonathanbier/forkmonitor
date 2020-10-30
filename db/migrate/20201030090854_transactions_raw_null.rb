class TransactionsRawNull < ActiveRecord::Migration[5.2]
  def up
    change_column :transactions, :raw, :binary, null: false
  end

  def down
    change_column :transactions, :raw, :binary, null: true
  end
end
