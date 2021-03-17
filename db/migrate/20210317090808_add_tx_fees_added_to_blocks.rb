class AddTxFeesAddedToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :tx_omitted_fee_rates, :integer, array: true
    add_column :block_templates, :tx_fee_rates, :integer, array: true
  end
end
