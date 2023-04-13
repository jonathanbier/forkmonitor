# frozen_string_literal: true

class BlockTemplate < ApplicationRecord
  include ::TxIdConcern
  enum coin: { btc: 0 }
  belongs_to :parent_block, class_name: 'Block', optional: true
  belongs_to :node

  def arr_tx_ids
    binary_to_hashes(tx_ids)
  end

  class << self
    def create_with(node, template)
      ActiveRecord::Base.transaction do
        parent_block = nil
        begin
          retries ||= 0
          parent_block = Block.find_by!(block_hash: template['previousblockhash'])
        rescue ActiveRecord::RecordNotFound
          Rails.logger.warn "Parent block #{template['previousblockhash']} not found yet..."
          retries += 1
          sleep 1
          retry if retries < 5
          Rails.logger.warn "Parent block #{template['previousblockhash']} not found after 5 seconds"
        end
        tx_ids = hashes_to_binary(template['transactions'].collect { |tx| tx['txid'] })
        template = create!(
          coin: node.coin,
          height: template['height'],
          parent_block: parent_block,
          node: node,
          fee_total: (template['coinbasevalue'] - Block.max_inflation(template['height'])) / 100_000_000.0,
          timestamp: Time.at(template['curtime']).utc,
          n_transactions: tx_ids.length / 32
        )
      end
    end

    def to_csv
      attributes = %w[height node_id timestamp fee_total n_transactions]

      CSV.generate(headers: true) do |csv|
        csv << attributes

        order(height: :desc).each do |template|
          csv << attributes.map { |attr| template.send(attr) }
        end
      end
    end
  end
end
