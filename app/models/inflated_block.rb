class InflatedBlock < ApplicationRecord
  belongs_to :block
  belongs_to :node
  belongs_to :comparison_block, class_name: 'Block'
  
  def as_json(options = nil)
    super({ only: [:id, :max_inflation, :actual_inflation, :dismissed_at] }).merge({
      coin: block.coin.upcase,
      extra_inflation: actual_inflation - max_inflation,
      block: block, 
      comparison_block: comparison_block,
      node: {
        id: node.id,
        name: node.name,
        name_with_version: node.name_with_version
      }
    })
  end
end
