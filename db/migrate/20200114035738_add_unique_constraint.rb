class AddUniqueConstraint < ActiveRecord::Migration[5.2]
  def change
    add_index :lightning_transactions, [:tx_id, :input], unique: true
  end
end
