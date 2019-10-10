class AddDismissedAtToInflatedBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :inflated_blocks, :dismissed_at, :datetime
  end
end
