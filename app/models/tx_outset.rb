class TxOutset < ApplicationRecord
  belongs_to :block
  belongs_to :node
end
