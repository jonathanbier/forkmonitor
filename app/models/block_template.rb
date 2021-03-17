class BlockTemplate < ApplicationRecord
  include ::TxIdConcern
  enum coin: [:btc, :bch, :bsv, :tbtc]
  belongs_to :parent_block, class_name: 'Block', optional: true
  belongs_to :node

  def arr_tx_ids
    binary_to_hashes(tx_ids)
  end

  def self.create_with(node, template)
    ActiveRecord::Base.transaction do
      parent_block = nil
      begin
        retries ||= 0
        parent_block = Block.find_by!(block_hash: template["previousblockhash"])
      rescue ActiveRecord::RecordNotFound
        Rails.logger.warn "Parent block #{ template["previousblockhash"] } not found yet..."
        retries += 1
        sleep 1
        retry if retries < 5
        Rails.logger.warn "Parent block #{ template["previousblockhash"] } not found after 5 seconds"
      end
      height = template["height"]
      tx_ids = hashes_to_binary(template["transactions"].collect{|tx| tx["txid"] })
      tx_fee_rates = template["transactions"].collect{|tx| tx["fee"] / (tx["weight"] / 4) }
      template = self.create!(
        coin: node.coin,
        height: template["height"],
        parent_block: parent_block,
        node: node,
        fee_total: (template["coinbasevalue"] - Block.max_inflation(template["height"])) / 100000000.0,
        timestamp: Time.at(template["curtime"]).utc,
        n_transactions: tx_ids.length / 32,
        tx_ids: tx_ids,
        tx_fee_rates: tx_fee_rates,
        lowest_fee_rate: tx_fee_rates.sort[0]
      )
      # TODO: when polling multiple nodes, the code below is repeated, and the
      #       block will use whatever we processed last.
      # Save space by cleaning up transaction ids and fees from earlier templates at this height:
      self.where(height: height, node: node).where.not(id: template.id).update_all tx_ids: nil, tx_fee_rates: nil
    end
  end

  def self.to_csv
    attributes = %w{height node_id timestamp fee_total n_transactions }

    CSV.generate(headers: true) do |csv|
      csv << attributes

      order(height: :desc).each do |template|
        csv << attributes.map{ |attr| template.send(attr) }
      end
    end
  end

end
