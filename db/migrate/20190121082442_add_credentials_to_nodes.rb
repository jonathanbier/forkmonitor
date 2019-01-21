class AddCredentialsToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :rpchost, :string
    add_column :nodes, :rpcuser, :string
    add_column :nodes, :rpcpassword, :string
  end
end
