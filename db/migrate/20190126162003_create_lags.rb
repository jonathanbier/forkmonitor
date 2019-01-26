class CreateLags < ActiveRecord::Migration[5.2]
  def change
    create_table :lags do |t|
      t.references :node_a, references: :node, index: true
      t.references :node_b, references: :node, index: true

      t.timestamps
    end
  end
end
