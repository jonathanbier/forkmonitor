# frozen_string_literal: true

class AddGetblocktemplateToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :getblocktemplate, :boolean, default: false, null: false
  end
end
