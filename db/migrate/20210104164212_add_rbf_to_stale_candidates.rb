# frozen_string_literal: true

class AddRbfToStaleCandidates < ActiveRecord::Migration[5.2]
  def change
    add_column :stale_candidates, :rbf, :string, array: true, default: [], null: false
    add_column :stale_candidates, :rbf_total, :decimal, precision: 16, scale: 8
  end
end
