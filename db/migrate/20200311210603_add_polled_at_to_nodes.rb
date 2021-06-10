# frozen_string_literal: true

class AddPolledAtToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :polled_at, :datetime
  end
end
