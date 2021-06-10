# frozen_string_literal: true

class RemoveCommonHeightFromNodes < ActiveRecord::Migration[5.2]
  def up
    remove_column :nodes, :common_height
    remove_column :nodes, :common_block_id
  end
end
