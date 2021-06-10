# frozen_string_literal: true

FactoryBot.define do
  factory :version_bit do
    bit { 1 }
    association :activate, factory: :block
    association :deactivate, factory: :block
  end
end
