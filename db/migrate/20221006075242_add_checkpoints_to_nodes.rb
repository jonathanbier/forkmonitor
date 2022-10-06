# frozen_string_literal: true

class AddCheckpointsToNodes < ActiveRecord::Migration[6.1]
  def change
    add_column :nodes, :checkpoints, :boolean, default: true, null: false
  end
end
