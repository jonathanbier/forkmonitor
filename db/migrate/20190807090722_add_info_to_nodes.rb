# frozen_string_literal: true

class AddInfoToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :pruned, :boolean, default: false, null: false
    add_column :nodes, :os, :string
    add_column :nodes, :cpu, :string
    add_column :nodes, :ram, :integer
    add_column :nodes, :storage, :string
    add_column :nodes, :cve_2018_17144, :boolean, default: false, null: false
    add_column :nodes, :released, :date
  end
end
