# frozen_string_literal: true

class AddClientToNodes < ActiveRecord::Migration[5.2]
  def up
    add_column :nodes, :client_type, :integer
    Node.where(is_core: true).update_all(client_type: :core)
    Node.where(name: 'Bitcoin ABC').update_all(client_type: :abc)
    Node.where(name: 'Bitcoin SV').update_all(client_type: :sv)
    Node.where(name: 'Bitcoin Knots').update_all(client_type: :knots)
    Node.where(name: 'bcoin').update_all(client_type: :bcoin)
    Node.where(name: 'btcd').update_all(client_type: :btcd)

    remove_column :nodes, :is_core
  end

  def down
    add_column :nodes, :is_core, :bool
    Node.where(client_type: :core).update_all(is_core: true)
  end
end
