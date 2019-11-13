class CreateLightningTransactions < ActiveRecord::Migration[5.2]
  def change
    create_table :lightning_transactions do |t|
      t.references :block, foreign_key: true
      t.string :tx_id
      t.string :raw_tx
      t.decimal :amount, precision: 16, scale: 8

      t.timestamps
    end
  end
end
