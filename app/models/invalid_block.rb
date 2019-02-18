class InvalidBlock < ApplicationRecord
  belongs_to :block
  belongs_to :node
end
