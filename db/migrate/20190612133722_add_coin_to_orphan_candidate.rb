# frozen_string_literal: true

class AddCoinToOrphanCandidate < ActiveRecord::Migration[5.2]
  def up
    add_column :orphan_candidates, :coin, :integer

    OrphanCandidate.update_all(coin: :btc)
  end

  def down
    remove_column :orphan_candidates, :coin
  end
end
