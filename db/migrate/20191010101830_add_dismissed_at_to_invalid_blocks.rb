# frozen_string_literal: true

class AddDismissedAtToInvalidBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :invalid_blocks, :dismissed_at, :datetime
  end
end
