class InvalidBlock < ApplicationRecord
  belongs_to :block
  belongs_to :node

  def as_json(options = nil)
    super({ only: [:id] }).merge({block: block, node: node})
  end
end
