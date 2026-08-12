# frozen_string_literal: true

class NodeBlock < ApplicationRecord
  belongs_to :node
  belongs_to :block
end
