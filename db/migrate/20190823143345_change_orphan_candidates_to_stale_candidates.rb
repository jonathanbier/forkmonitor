class ChangeOrphanCandidatesToStaleCandidates < ActiveRecord::Migration[5.2]
  def change
    rename_table :orphan_candidates, :stale_candidates
  end
end
