class AddHeightProcessedToStaleCandidates < ActiveRecord::Migration[5.2]
  def change
    add_column :stale_candidates, :height_processed, :int
  end
end
