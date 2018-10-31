class CreateBlocks < ActiveRecord::Migration[5.2]
  def change
    create_table :blocks do |t|
      t.string :block_hash
      t.integer :height
      t.integer :timestamp
      t.string :work

      t.timestamps
    end
    add_index :blocks, :block_hash, unique: true
  end
end
