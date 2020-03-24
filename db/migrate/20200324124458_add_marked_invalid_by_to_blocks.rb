class AddMarkedInvalidByToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :marked_invalid_by, :integer, array: true, default: []
  end
end
