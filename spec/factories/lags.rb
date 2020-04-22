FactoryBot.define do
   factory :lag do
     association :node_a, factory: :node_with_chaintip, version: 100300
     association :node_b, factory: :node_with_chaintip
   end
 end
