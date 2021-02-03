class BlockTemplate < ApplicationRecord
  belongs_to :parent_block, class_name: 'Block'
  belongs_to :node

  def self.create_with(node, template)
    self.create!(
      height: template["height"],
      parent_block: Block.find_by(block_hash: template["previousblockhash"]),
      node: node,
      fee_total: (template["coinbasevalue"] - Block.max_inflation(template["height"])) / 100000000.0,
      timestamp: Time.at(template["curtime"]).utc
    )
  end

  def self.to_csv
    attributes = %w{height node_id timestamp fee_total }

    CSV.generate(headers: true) do |csv|
      csv << attributes

      order(height: :desc).each do |template|
        csv << attributes.map{ |attr| template.send(attr) }
      end
    end
  end
end
