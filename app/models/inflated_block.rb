class InflatedBlock < ApplicationRecord
  belongs_to :block
  belongs_to :node
  belongs_to :comparison_block, class_name: 'Block'
  
  def as_json(options = nil)
    super({ only: [:id] }).merge({block: block, node: {
      id: node.id,
      name: node.name,
      name_with_version: node.name_with_version
    }})
  end
end
