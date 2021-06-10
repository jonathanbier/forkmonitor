# frozen_string_literal: true

class AddDoubleSpentByToStaleCandidates < ActiveRecord::Migration[5.2]
  def change
    add_column :stale_candidates, :double_spent_by, :string, array: true, default: [], null: false
    add_column :stale_candidates, :rbf_by, :string, array: true, default: [], null: false
  end
end
