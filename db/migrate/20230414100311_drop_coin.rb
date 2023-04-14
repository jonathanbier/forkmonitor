class DropCoin < ActiveRecord::Migration[6.1]
  def up
    BlockTemplate.where.not(coin: "btc").destroy_all
    Chaintip.where.not(coin: "btc").destroy_all
    Softfork.where.not(coin: "btc").destroy_all
    StaleCandidate.where.not(coin: "btc").destroy_all
    Block.where.not(coin: "btc").destroy_all
    Node.where.not(coin: "btc").destroy_all

    remove_column :nodes, :coin
    remove_column :chaintips, :coin
    remove_column :blocks, :coin
    remove_column :softforks, :coin
    remove_column :stale_candidates, :coin
    remove_column :block_templates, :coin
  end
end
