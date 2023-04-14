class DropTemplates < ActiveRecord::Migration[6.1]
  def up
    remove_column :blocks, :template_txs_fee_diff
    remove_column :nodes, :getblocktemplate
    drop_table :block_templates
  end
end
