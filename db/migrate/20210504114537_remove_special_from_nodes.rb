# frozen_string_literal: true

class RemoveSpecialFromNodes < ActiveRecord::Migration[6.1]
  def change
    remove_column :nodes, :special, :bool, null: false, default: false
  end
end
