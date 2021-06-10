# frozen_string_literal: true

class AddMirrorUnreachableSinceToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :mirror_unreachable_since, :datetime
    add_column :nodes, :last_polled_mirror_at, :datetime
  end
end
