class AddTxIdsToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :tx_ids, :binary
  end
end
