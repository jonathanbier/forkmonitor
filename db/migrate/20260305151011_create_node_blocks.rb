# frozen_string_literal: true

class CreateNodeBlocks < ActiveRecord::Migration[6.1]
  def change
    create_table :node_blocks do |t|
      t.references :node, null: false, foreign_key: true
      t.references :block, null: false, foreign_key: true
      t.datetime :first_seen_at, null: false

      t.timestamps
    end

    add_index :node_blocks, %i[node_id block_id], unique: true
  end
end
