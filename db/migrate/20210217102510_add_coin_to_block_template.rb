class AddCoinToBlockTemplate < ActiveRecord::Migration[5.2]
  def up
    add_column :block_templates, :coin, :integer
    BlockTemplate.update_all coin: :btc
    change_column :block_templates, :coin, :integer, null: false
  end
end
