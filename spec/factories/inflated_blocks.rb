FactoryBot.define do
   factory :inflated_block do
     association :node, factory: :node_with_block
     association :block, factory: :block_first_seen_by
     actual_inflation { 13.5 }
     max_inflation { 12.5 }
   end
 end
