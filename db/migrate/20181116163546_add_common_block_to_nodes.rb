class AddCommonBlockToNodes < ActiveRecord::Migration[5.2]
  def change
    add_reference :nodes, :common_block, references: :block, index: true
  end
end
