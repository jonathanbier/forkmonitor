# frozen_string_literal: true

class AddPortToNodes < ActiveRecord::Migration[5.2]
  def up
    add_column :nodes, :rpcport, :integer

    Node.all.each do |node|
      (host, port) = node.rpchost.split(':')
      node.update rpchost: host, rpcport: port
    end
  end
end
