class CreateSoftforks < ActiveRecord::Migration[5.2]
  def change
    create_table :softforks do |t|
      t.integer :coin
      t.references :node
      t.integer :fork_type
      t.string :name
      t.integer :bit
      t.integer :status
      t.integer :since

      t.timestamps
    end
  end
end
