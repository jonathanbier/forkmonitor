class Node < ApplicationRecord
  belongs_to :block
  belongs_to :common_block, foreign_key: "common_block_id", class_name: "Block", required: false

  default_scope { includes(:block).order("blocks.work desc", name: :asc, version: :desc) }

  def as_json(options = nil)
    super({ only: [:pos, :name, :version, :unreachable_since] }.merge(options || {})).merge({best_block: block, common_block: common_block})
  end
end
