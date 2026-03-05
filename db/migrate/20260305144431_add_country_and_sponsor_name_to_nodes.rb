# frozen_string_literal: true

class AddCountryAndSponsorNameToNodes < ActiveRecord::Migration[6.1]
  def change
    add_column :nodes, :country, :string
    add_column :nodes, :sponsor_name, :string
  end
end
