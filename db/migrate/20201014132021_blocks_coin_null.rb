# frozen_string_literal: true

class BlocksCoinNull < ActiveRecord::Migration[5.2]
  def up
    change_column :blocks, :coin, :integer, null: false
    change_column :blocks, :height, :integer, null: false
  end

  def down
    change_column :blocks, :coin, :integer, null: true
    change_column :blocks, :height, :integer, null: true
  end
end
