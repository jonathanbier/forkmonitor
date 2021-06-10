# frozen_string_literal: true

FactoryBot.define do
  factory :invalid_block do
    association :node, factory: :node_with_block
    association :block, factory: :block_first_seen_by
  end
end
