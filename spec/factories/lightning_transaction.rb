FactoryBot.define do
   factory :lightning_transaction do
     association :block
     tx_id { "c64564a132778ba71ffb6188f7b92dac7c5d22afabeaec31f130bbd201ebb1b6" }
     amount { 1.33874639 }
   end
 end
