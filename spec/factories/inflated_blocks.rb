FactoryBot.define do
   factory :inflated_block do
     association :comparison_block, factory: :block_first_seen_by
     association :block, factory: :block_first_seen_by
     actual_inflation { 13.5 }
     max_inflation { 12.5 }
   end
 end
