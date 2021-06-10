# frozen_string_literal: true

class MakeStaleBlockUnique < ActiveRecord::Migration[5.2]
  def up
    ids = StaleCandidate.group(:coin, :height).pluck('min(id)')
    StaleCandidate.where.not(id: ids).destroy_all

    add_index :stale_candidates, %i[coin height], unique: true
  end
end
