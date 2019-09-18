class ChangeInflationToBeDecimalInInflatedBlocks < ActiveRecord::Migration[5.2]
  def change
    change_column :inflated_blocks, :max_inflation, :decimal, precision: 16, scale: 8
    change_column :inflated_blocks, :actual_inflation, :decimal, precision: 16, scale: 8
  end
end
