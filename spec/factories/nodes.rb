FactoryBot.define do
   factory :node do
     coin { "BTC"}
     name { "Bitcoin Core" }
     client_type { :core }
   end

   factory :node_with_block, parent: :node do
     block
   end
   
   factory :node_with_mirror, parent: :node do
     mirror_rpchost { "127.0.0.1" }
     mirror_rpcport { 8336 }
   end
 end
