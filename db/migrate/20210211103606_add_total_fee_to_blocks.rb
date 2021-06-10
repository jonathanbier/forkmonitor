# frozen_string_literal: true

class AddTotalFeeToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :total_fee, :decimal, precision: 16, scale: 8
  end
end
