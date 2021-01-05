class AddIndexToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_index :blocks, :height
    add_index :blocks, :work
    add_index :transactions, :is_coinbase
  end
end
