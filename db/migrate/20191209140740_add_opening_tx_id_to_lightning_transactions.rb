class AddOpeningTxIdToLightningTransactions < ActiveRecord::Migration[5.2]
  def up
    add_column :lightning_transactions, :opening_tx_id, :string

    LightningTransaction.all.each do |ln|
      ln.update opening_tx_id: ln.get_opening_tx_id!
    end
  end
end
