# frozen_string_literal: true

class CreateTxOutsets < ActiveRecord::Migration[5.2]
  def change
    create_table :tx_outsets do |t|
      t.references :block, foreign_key: true
      t.integer :txouts
      t.decimal :total_amount, precision: 16, scale: 8

      t.timestamps
    end
  end
end
