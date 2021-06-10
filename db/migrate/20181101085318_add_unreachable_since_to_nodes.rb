# frozen_string_literal: true

class AddUnreachableSinceToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :unreachable_since, :datetime
  end
end
