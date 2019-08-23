class InflatedBlock < ApplicationRecord
  belongs_to :block
  belongs_to :comparison_block, class_name: 'Block'
end
