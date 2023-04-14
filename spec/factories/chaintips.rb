# frozen_string_literal: true

FactoryBot.define do
  factory :chaintip do
    node
    block
    status { :active }
  end
end
