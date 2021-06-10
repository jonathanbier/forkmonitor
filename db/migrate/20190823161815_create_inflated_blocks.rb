# frozen_string_literal: true

class CreateInflatedBlocks < ActiveRecord::Migration[5.2]
  def change
    create_table :inflated_blocks do |t|
      t.references :block, foreign_key: true
      t.references :comparison_block, foreign_key: { to_table: :blocks }
      t.integer :max_inflation
      t.integer :actual_inflation
      t.datetime :notified_at

      t.timestamps
    end
  end
end
