# frozen_string_literal: true

class Lag < ApplicationRecord
  belongs_to :node_a, class_name: 'Node'
  belongs_to :node_b, class_name: 'Node'
end
