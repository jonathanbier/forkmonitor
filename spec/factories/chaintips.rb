FactoryBot.define do
   factory :chaintip do
     coin { :btc }
     node
     block
     status { :active }
   end
 end
