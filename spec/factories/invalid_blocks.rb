FactoryBot.define do
   factory :invalid_block do
     association :node, factory: :node_with_block, version: 170100
     association :block, factory: :block
   end
 end
