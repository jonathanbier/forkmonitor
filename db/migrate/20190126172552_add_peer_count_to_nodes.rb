class AddPeerCountToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :peer_count, :int
  end
end
