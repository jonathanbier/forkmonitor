# frozen_string_literal: true

class AddVersionExtraToNode < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :version_extra, :string, default: '', null: false
  end
end
