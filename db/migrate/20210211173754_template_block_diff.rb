# frozen_string_literal: true

class TemplateBlockDiff < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :tx_ids_added, :binary
    add_column :blocks, :tx_ids_omitted, :binary
  end
end
