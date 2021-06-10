# frozen_string_literal: true

class AddConnectedToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :connected, :boolean, default: false
  end
end
