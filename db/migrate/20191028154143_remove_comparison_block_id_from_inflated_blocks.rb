# frozen_string_literal: true

class RemoveComparisonBlockIdFromInflatedBlocks < ActiveRecord::Migration[5.2]
  def change
    remove_column :inflated_blocks, :comparison_block_id
  end
end
