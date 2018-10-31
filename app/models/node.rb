class Node < ApplicationRecord
  belongs_to :block

  def as_json(options = nil)
    super({ only: [:pos, :name, :version] }.merge(options || {})).merge({best_block: block})
  end
end
