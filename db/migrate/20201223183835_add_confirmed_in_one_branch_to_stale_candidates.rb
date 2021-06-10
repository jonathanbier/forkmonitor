# frozen_string_literal: true

class AddConfirmedInOneBranchToStaleCandidates < ActiveRecord::Migration[5.2]
  def change
    add_column :stale_candidates, :confirmed_in_one_branch, :string, array: true, default: []
    add_column :stale_candidates, :confirmed_in_one_branch_total, :decimal, precision: 16, scale: 8
    add_column :stale_candidates, :double_spent_in_one_branch, :string, array: true, default: []
    add_column :stale_candidates, :double_spent_in_one_branch_total, :decimal, precision: 16, scale: 8
  end
end
