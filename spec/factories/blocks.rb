# frozen_string_literal: true

FactoryBot.define do
  factory :block do
    sequence(:block_hash) { |n| n.to_s(16).rjust(32, '0') }
    sequence(:height) { |n| 500_000 + n }
    sequence(:timestamp) { |n| 1_500_000_000 + (60 * 10 * n) }
    sequence(:work) { |n| n.to_s(16).rjust(32, '0') }
    coin { :btc }
    version { 0x20000000 }
  end

  factory :block_first_seen_by, parent: :block do
    association :first_seen_by, factory: :node_with_block, version: 160_100
  end

  factory :lightning_block, parent: :block do
    block_hash { '00000000000000000008647bf3adffc88909838e32b9543d77086fb8dc6e40a5' }
    height { 602_649 }
  end
end
