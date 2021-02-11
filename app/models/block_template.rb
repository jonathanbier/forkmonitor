class BlockTemplate < ApplicationRecord
  belongs_to :parent_block, class_name: 'Block', optional: true
  belongs_to :node

  def arr_tx_ids
    BlockTemplate.binary_to_hashes(tx_ids)
  end

  def self.create_with(node, template)
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
    tx_ids = self.hashes_to_binary(template["transactions"].collect{|tx| tx["txid"] })
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

  def self.get_binary_chunks(data, size)
    Array.new(((data.length + size - 1) / size)) { |i| data.byteslice(i * size, size) }
  end

  def self.hashes_to_binary(hashes)
    hashes.collect {|hash|
      [hash].pack("H*")
    }.join()
  end

  def self.binary_to_hashes(binary)
    self.get_binary_chunks(binary,32).collect {|chunck|
      chunck.unpack("H*")[0]
    }
  end
end
