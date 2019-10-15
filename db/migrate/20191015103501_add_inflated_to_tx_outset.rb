class AddInflatedToTxOutset < ActiveRecord::Migration[5.2]
  def change
    add_column :tx_outsets, :inflated, :boolean, null: false, default: false
  end
end
