# frozen_string_literal: true

class AddIsCoreToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :is_core, :boolean, default: false
  end
end
