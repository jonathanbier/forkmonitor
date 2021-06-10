# frozen_string_literal: true

class CreateInvalidBlocks < ActiveRecord::Migration[5.2]
  def change
    create_table :invalid_blocks do |t|
      t.references :block, foreign_key: true
      t.references :node, foreign_key: true
      t.datetime :notified_at

      t.timestamps
    end
  end
end
