# frozen_string_literal: true

class StaleCandidateNotNull < ActiveRecord::Migration[5.2]
  def up
    StaleCandidate.where(double_spent_in_one_branch: nil).update_all double_spent_in_one_branch: []
    StaleCandidate.where(confirmed_in_one_branch: nil).update_all confirmed_in_one_branch: []
    change_column :stale_candidates, :double_spent_in_one_branch, :string, array: true, null: false, default: []
    change_column :stale_candidates, :confirmed_in_one_branch, :string, array: true, null: false, default: []
  end
end
