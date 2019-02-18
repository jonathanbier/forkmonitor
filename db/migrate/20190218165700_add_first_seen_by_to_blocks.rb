class AddFirstSeenByToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_reference :blocks, :first_seen_by, foreign_key: { to_table: :nodes }
  end
end
