class AddPythonToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :python, :boolean, default: false, null: false
  end
end
