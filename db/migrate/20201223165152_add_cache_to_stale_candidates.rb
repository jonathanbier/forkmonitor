# frozen_string_literal: true

class AddCacheToStaleCandidates < ActiveRecord::Migration[5.2]
  def change
    add_column :stale_candidates, :n_children, :int, default: nil
  end
end
