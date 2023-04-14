class DropTestnet < ActiveRecord::Migration[6.1]
  def up
    BlockTemplate.where(coin: 3).delete_all
    Chaintip.where(coin: 3).destroy_all
    Softfork.where(coin: 3).destroy_all
    StaleCandidate.where(coin: 3).destroy_all
    TxOutset.joins(:node).where("nodes.coin = ?", 3).destroy_all
    Transaction.joins(:block).where("coin = ?", 3).delete_all
    Node.where(coin: 3).update block:nil, mirror_block: nil
    Block.where(coin: 3).delete_all
    Node.where(coin: 3).destroy_all
  end
end
