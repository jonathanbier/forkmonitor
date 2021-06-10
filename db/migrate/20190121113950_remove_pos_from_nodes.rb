# frozen_string_literal: true

class RemovePosFromNodes < ActiveRecord::Migration[5.2]
  def change
    remove_column :nodes, :pos, :string
  end
end
