class AddBlocksToLags < ActiveRecord::Migration[5.2]
  def change
    add_column :lags, :blocks, :integer, default: 0
  end
end
