# frozen_string_literal: true

class VersionBit < ApplicationRecord
  WINDOW = Rails.env.test? ? 3 : 100
  belongs_to :activate, foreign_key: 'activate_block_id', class_name: 'Block'
  belongs_to :deactivate, foreign_key: 'deactivate_block_id', class_name: 'Block', optional: true
end
