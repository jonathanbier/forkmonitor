class AddStatsToBlock < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :tx_count, :integer
    add_column :blocks, :size, :integer
  end
end
