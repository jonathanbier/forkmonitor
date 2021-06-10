# frozen_string_literal: true

class AddMirrorIbdToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :mirror_ibd, :boolean, null: false, default: false
  end
end
