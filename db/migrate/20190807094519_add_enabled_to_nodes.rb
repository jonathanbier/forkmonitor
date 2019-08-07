class AddEnabledToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :enabled, :boolean, default: true, null: false
  end
end
