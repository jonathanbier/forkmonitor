# frozen_string_literal: true

class AddUniqueConstraint < ActiveRecord::Migration[5.2]
  def change
    add_index :lightning_transactions, %i[tx_id input], unique: true
  end
end
