class VersionBit < ApplicationRecord
  belongs_to :activate, foreign_key: "activate_block_id", class_name: "Block"
  belongs_to :deactivate, foreign_key: "deactivate_block_id", class_name: "Block", required: false
end
