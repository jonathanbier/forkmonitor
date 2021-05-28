FactoryBot.define do
  factory :pool do
  end

  factory :antpool, parent: :pool do
    tag { "Mined by AntPool" }
    name { "Antpool" }
  end

  factory :f2pool, parent: :pool do
    tag { "🐟" }
    name { "F2Pool" }
  end
end
