# frozen_string_literal: true

class AddMarkedValidByToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :marked_valid_by, :integer, array: true, default: []
  end
end
