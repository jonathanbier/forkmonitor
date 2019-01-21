class AddCommonHeightToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :common_height, :integer
  end
end
