# frozen_string_literal: true

class CreateTransactions < ActiveRecord::Migration[5.2]
  def change
    create_table :transactions do |t|
      t.references :block, foreign_key: true
      t.string :tx_id, limit: 64, null: false, index: true
      t.boolean :is_coinbase, null: false

      t.timestamps
    end
  end
end
