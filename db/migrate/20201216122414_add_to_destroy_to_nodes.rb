# frozen_string_literal: true

class AddToDestroyToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :to_destroy, :bool, default: false, null: false
  end
end
