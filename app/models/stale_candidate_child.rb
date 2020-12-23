class StaleCandidateChild < ApplicationRecord
  belongs_to :stale_candidate
  belongs_to :root, class_name: "Block"
  belongs_to :tip, class_name: "Block"

  def as_json(options = nil)
    super({ only: [:length] }).merge({
      root: root,
      tip: tip
    })
  end
end
