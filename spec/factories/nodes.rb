FactoryBot.define do
   factory :node do
     block
     sequence(:version) { |n| n * 10000 }
     sequence(:pos) { |n| n }
     name { "Bitcoin Core" }
   end
 end
