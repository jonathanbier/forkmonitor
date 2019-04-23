FactoryBot.define do
   factory :node do
     coin { "BTC"}
     name { "Bitcoin Core" }
     is_core { true }
   end

   factory :node_with_block, parent: :node do
     block
   end
 end
