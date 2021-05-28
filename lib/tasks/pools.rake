require 'net/http'
require 'json'

namespace 'pools' do :env
  desc "Update pool database"
  task :fetch => :environment do |action|
    Pool.fetch!
  end
end
