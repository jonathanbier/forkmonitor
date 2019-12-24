class AddChannelPublicToLightningTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :lightning_transactions, :channel_is_public, :boolean
    add_column :lightning_transactions, :channel_id_1ml, :bigint
  end
end
