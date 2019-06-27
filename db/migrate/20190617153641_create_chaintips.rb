class CreateChaintips < ActiveRecord::Migration[5.2]
  def up
    create_table :chaintips do |t|
      t.references :node, foreign_key: true
      t.references :block, foreign_key: true
      t.references :parent_chaintip,foreign_key: { to_table: :chaintips }
      t.integer :coin, null: false
      t.string :status, null: false

      t.timestamps
    end
  end

  def down
    drop_table :chaintips
  end
end
