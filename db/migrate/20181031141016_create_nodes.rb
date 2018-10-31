class CreateNodes < ActiveRecord::Migration[5.2]
  def change
    create_table :nodes do |t|
      t.integer :pos
      t.string :name
      t.integer :version
      t.references :block, foreign_key: true

      t.timestamps
    end
  end
end
