class AddMediantimeToBlocks < ActiveRecord::Migration[5.2]
  def up
    add_column :blocks, :mediantime, :integer
    Block.update_all("mediantime=timestamp")
  end

  def down
    remove_column :blocks, :mediantime
  end
end
