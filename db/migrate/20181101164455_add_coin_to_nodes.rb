class AddCoinToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :coin, :string
  end
end
