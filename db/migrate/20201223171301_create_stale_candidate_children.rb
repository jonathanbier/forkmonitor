# frozen_string_literal: true

class CreateStaleCandidateChildren < ActiveRecord::Migration[5.2]
  def change
    create_table :stale_candidate_children do |t|
      t.references :stale_candidate, foreign_key: true
      t.references :root, foreign_key: { to_table: :blocks }
      t.references :tip, foreign_key: { to_table: :blocks }
      t.integer :length

      t.timestamps
    end
    remove_column :stale_candidates, :n_children, :int
  end
end
