# frozen_string_literal: true

FactoryBot.define do
  factory :pool

  factory :antpool, parent: :pool do
    tag { 'Mined by AntPool' }
    name { 'Antpool' }
  end

  factory :f2pool, parent: :pool do
    tag { '🐟' }
    name { 'F2Pool' }
  end
end
