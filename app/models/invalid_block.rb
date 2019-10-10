class InvalidBlock < ApplicationRecord
  belongs_to :block
  belongs_to :node

  def as_json(options = nil)
    super({ only: [:id, :dismissed_at] }).merge({block: block, node: {
      id: node.id,
      name: node.name,
      name_with_version: node.name_with_version
    }})
  end
end
