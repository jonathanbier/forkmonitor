class AddParentToBlock < ActiveRecord::Migration[5.2]
  def change
    add_reference :blocks, :parent, index: true
  end
end
