FactoryBot.define do
   factory :node do
     name { "Bitcoin Core" }
   end

   factory :node_with_block, parent: :node do
     block
   end
 end
