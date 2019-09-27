class AddMirrorToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :mirror_rpchost, :string
    add_column :nodes, :mirror_rpcport, :integer
    add_column :nodes, :mirror_block_id, :bigint
    add_index :nodes, :mirror_block_id
  end
end
