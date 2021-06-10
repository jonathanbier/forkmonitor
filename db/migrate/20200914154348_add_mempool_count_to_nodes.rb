# frozen_string_literal: true

class AddMempoolCountToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :mempool_count, :integer
    add_column :nodes, :mempool_bytes, :integer
    add_column :nodes, :mempool_max, :integer
  end
end
