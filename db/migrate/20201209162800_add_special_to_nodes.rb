# frozen_string_literal: true

class AddSpecialToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :special, :bool, null: false, default: false
  end
end
