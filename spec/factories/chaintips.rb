# frozen_string_literal: true

FactoryBot.define do
  factory :chaintip do
    coin { :btc }
    node
    block
    status { :active }
  end
end
