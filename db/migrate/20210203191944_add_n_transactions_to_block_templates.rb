# frozen_string_literal: true

class AddNTransactionsToBlockTemplates < ActiveRecord::Migration[5.2]
  def change
    add_column :block_templates, :n_transactions, :integer, null: false
  end
end
