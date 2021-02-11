class AddTemplateTxsFeeDiffToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :template_txs_fee_diff, :decimal, precision: 16, scale: 8
  end
end
