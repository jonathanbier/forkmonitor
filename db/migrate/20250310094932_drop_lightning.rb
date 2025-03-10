class DropLightning < ActiveRecord::Migration[6.1]
  def up
    remove_foreign_key "lightning_transactions", "blocks"

    drop_table :lightning_transactions

    remove_column :blocks, :checked_lightning
  end
end
