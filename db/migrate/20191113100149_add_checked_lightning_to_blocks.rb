class AddCheckedLightningToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :checked_lightning, :boolean, default: false
  end
end
