class CreateVersionBits < ActiveRecord::Migration[5.2]
  def change
    create_table :version_bits do |t|
      t.integer :bit
      t.references :activate_block, foreign_key: { to_table: :blocks }
      t.references :deactivate_block, foreign_key: { to_table: :blocks }
      t.datetime :notified_at

      t.timestamps
    end
  end
end
