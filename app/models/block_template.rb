class BlockTemplate < ApplicationRecord
  belongs_to :parent_block, class_name: 'Block', optional: true
  belongs_to :node

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
    self.create!(
      height: template["height"],
      parent_block: parent_block,
      node: node,
      fee_total: (template["coinbasevalue"] - Block.max_inflation(template["height"])) / 100000000.0,
      timestamp: Time.at(template["curtime"]).utc,
      n_transactions: template["transactions"].count
    )
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
