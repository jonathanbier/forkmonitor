class RemoveTxIdsFromBlocks < ActiveRecord::Migration[6.1]
  def up
    remove_column :blocks, :tx_ids
    remove_column :blocks, :tx_ids_added
    remove_column :blocks, :tx_ids_omitted
    remove_column :blocks, :tx_omitted_fee_rates
    remove_column :blocks, :lowest_template_fee_rate
  end
end
