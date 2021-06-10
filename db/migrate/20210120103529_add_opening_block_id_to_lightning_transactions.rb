# frozen_string_literal: true

class AddOpeningBlockIdToLightningTransactions < ActiveRecord::Migration[5.2]
  def change
    add_reference :lightning_transactions, :opening_block, references: :block
  end
end
