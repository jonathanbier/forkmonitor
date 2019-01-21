FactoryBot.define do
   factory :node do
     block
     sequence(:version) { |n| n * 10000 }
     name { "Bitcoin Core" }
   end
 end
