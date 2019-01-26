FactoryBot.define do
   factory :user do
     email { FFaker::Internet.email }
     password { "123456" }
     confirmed_at { Time.now }
   end
 end
