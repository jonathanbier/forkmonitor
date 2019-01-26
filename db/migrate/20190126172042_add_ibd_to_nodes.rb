class AddIbdToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :ibd, :boolean
  end
end
