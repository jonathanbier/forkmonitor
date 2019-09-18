class AddNodeToInflatedBlocks < ActiveRecord::Migration[5.2]
  def change
    add_reference :inflated_blocks, :node, foreign_key: true
  end
end
