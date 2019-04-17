class CreateOrphanCandidates < ActiveRecord::Migration[5.2]
  def change
    create_table :orphan_candidates do |t|
      t.integer :height
      t.datetime :notified_at

      t.timestamps
    end
  end
end
