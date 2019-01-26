FactoryBot.define do
   factory :lag do
     association :node_a, factory: :node_with_block, version: 100300
     association :node_b, factory: :node_with_block, version: 170100
   end
 end
