# frozen_string_literal: true

class AddTxIdsToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :tx_ids, :binary
  end
end
