class RemoveTxIdsFromBlockTemplates < ActiveRecord::Migration[6.1]
  def up
    remove_column :block_templates, :tx_ids
    remove_column :block_templates, :tx_fee_rates
    remove_column :block_templates, :lowest_fee_rate
  end
end
