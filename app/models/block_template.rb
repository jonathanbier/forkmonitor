class BlockTemplate < ApplicationRecord
  include ::TxIdConcern
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
      template = self.create!(
        height: template["height"],
        parent_block: parent_block,
        node: node,
        fee_total: (template["coinbasevalue"] - Block.max_inflation(template["height"])) / 100000000.0,
        timestamp: Time.at(template["curtime"]).utc,
        n_transactions: tx_ids.length / 32,
        tx_ids: tx_ids
      )
      # Safe space by cleaning up transaction ids from earlier templates at this height:
      self.where(height: height, node: node).where.not(id: template.id).update_all tx_ids: nil

      # If this is the first template at a new height, and we have the parent block,
      # process stats for the previous block:
      if parent_block.present? && self.where(parent_block: parent_block, node: node).count == 1
        last_template = BlockTemplate.where(height: height - 1, node: node).where.not(tx_ids: nil).last
        unless last_template.nil? || parent_block.total_fee.nil?
          template_tx_ids = BlockTemplate.get_binary_chunks(last_template.tx_ids,32)
          block_tx_ids = BlockTemplate.get_binary_chunks(parent_block.tx_ids,32)
          # * fee difference
          # * transactions in template that are missing in the block, and;
          # * those in the block that were not in the template:
          parent_block.update template_txs_fee_diff: parent_block.total_fee - last_template.fee_total,
                              tx_ids_added: (block_tx_ids - template_tx_ids).join(),
                              tx_ids_omitted: (template_tx_ids - block_tx_ids).join()
        end
      end
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
