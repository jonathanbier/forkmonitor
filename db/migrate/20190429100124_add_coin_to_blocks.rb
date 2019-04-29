class AddCoinToBlocks < ActiveRecord::Migration[5.2]
  def up
    add_column :blocks, :coin, :integer
    Block.where(is_btc: true).update_all(coin: :btc)
    add_index :blocks, :coin
    remove_column :blocks, :is_btc

    # Be sure to change nodes.coin from "BCH" to "BSV" first!
    Node.where(coin: "BCH").each do |node|
      Block.where(first_seen_by_id: node.id).update_all(coin: :bch)
    end

    Node.where(coin: "BSV").each do |node|
      Block.where(first_seen_by_id: node.id).update_all(coin: :bsv)
    end
  end

  def down
    add_column :blocks, :is_btc, :bool
    Block.where(coin: :btc).update_all(is_btc: true)
    remove_index :blocks, :coin
    remove_column :blocks, :coin
  end
end
