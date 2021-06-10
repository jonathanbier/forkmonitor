# frozen_string_literal: true

namespace 'cache' do
  :env
  desc 'Clear Rails cache'
  task clear: :environment do
    Rails.cache.clear
  end
end
