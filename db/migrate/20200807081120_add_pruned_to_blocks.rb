# frozen_string_literal: true

class AddPrunedToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :pruned, :boolean
  end
end
