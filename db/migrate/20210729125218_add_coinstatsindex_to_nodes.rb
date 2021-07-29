# frozen_string_literal: true

class AddCoinstatsindexToNodes < ActiveRecord::Migration[6.1]
  def change
    add_column :nodes, :coinstatsindex, :boolean, default: nil
  end
end
