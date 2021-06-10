# frozen_string_literal: true

class AddTimeoutToMirrorNode < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :mirror_rest_until, :datetime
  end
end
