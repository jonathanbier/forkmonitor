class AddCoinbaseMessageBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :coinbase_message, :string
  end
end
