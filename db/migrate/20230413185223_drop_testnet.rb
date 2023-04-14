class DropTestnet < ActiveRecord::Migration[6.1]
  def up
    BlockTemplate.where(coin: 3).delete_all
    Chaintip.where(coin: 3).destroy_all
    Softfork.where(coin: 3).destroy_all
    StaleCandidate.where(coin: 3).destroy_all
    Block.where(coin: 3).delete_all
    Node.where(coin: 3).destroy_all
  end
end
