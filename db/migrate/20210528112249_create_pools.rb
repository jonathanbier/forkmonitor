# frozen_string_literal: true

class CreatePools < ActiveRecord::Migration[6.1]
  def change
    create_table :pools do |t|
      t.string :tag
      t.string :name
      t.string :url

      t.timestamps
    end

    add_index :pools, :tag
  end
end
