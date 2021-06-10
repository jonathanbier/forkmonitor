# frozen_string_literal: true

class AddSyncHeightToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :sync_height, :integer
  end
end
