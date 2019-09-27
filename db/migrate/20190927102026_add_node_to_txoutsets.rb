class AddNodeToTxoutsets < ActiveRecord::Migration[5.2]
  def up
    add_reference :tx_outsets, :node, foreign_key: true
    node = Node.bitcoin_core_by_version.first
    TxOutset.update_all node_id: node.id
  end
end
