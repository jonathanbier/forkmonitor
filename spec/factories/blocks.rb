FactoryBot.define do
   factory :block do
     sequence(:block_hash) { |n| n.to_s(16).rjust(32,"0") }
     sequence(:height) { |n| 500000 + n }
     sequence(:timestamp) { |n| 1500000000 + 60 * 10 * n }
     sequence(:work) { |n| n.to_s(16).rjust(32,"0") }
     coin { :btc }
     version { 0x20000000 }
   end

   factory :block_first_seen_by, parent: :block do
     association :first_seen_by, factory: :node_with_block, version: 160100
   end

   factory :lightning_block, parent: :block do
      block_hash { "00000000000000000008647bf3adffc88909838e32b9543d77086fb8dc6e40a5" }
      height { 602649 }
   end

 end
