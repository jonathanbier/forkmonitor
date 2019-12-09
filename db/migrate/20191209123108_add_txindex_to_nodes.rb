class AddTxindexToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :txindex, :boolean, default: false, null: false
  end
end
