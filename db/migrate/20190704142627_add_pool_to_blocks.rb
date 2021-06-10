# frozen_string_literal: true

class AddPoolToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :pool, :string
  end
end
