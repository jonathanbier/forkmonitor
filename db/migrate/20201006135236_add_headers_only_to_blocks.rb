# frozen_string_literal: true

class AddHeadersOnlyToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :headers_only, :bool, default: false, null: false
  end
end
