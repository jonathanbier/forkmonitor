class CreateBlockTemplates < ActiveRecord::Migration[5.2]
  def change
    create_table :block_templates do |t|
      t.references :parent_block, references: :block, index: true
      t.references :node, foreign_key: true
      t.decimal :fee_total, precision: 16, scale: 8
      t.datetime :timestamp
      t.integer :height

      t.timestamps
    end
  end
end
