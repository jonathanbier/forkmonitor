# frozen_string_literal: true

class AddMissingTransactionsToStaleCandidates < ActiveRecord::Migration[5.2]
  def up
    add_column :stale_candidates, :missing_transactions, :boolean, default: false, null: false
  end
end
