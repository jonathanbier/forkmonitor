class MakeNodeCoinEnum < ActiveRecord::Migration[5.2]
  def up
    rename_column :nodes, :coin, :coin_old
    add_column :nodes, :coin, :integer
    Node.all.each do |node|
      node.update coin: node.coin_old.downcase.to_sym
    end
    change_column :nodes, :coin, :integer, null: false
    remove_column :nodes, :coin_old
  end
end
