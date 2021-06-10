# frozen_string_literal: true

class TemplateTxs < ActiveRecord::Migration[5.2]
  def change
    add_column :block_templates, :tx_ids, :binary
  end
end
