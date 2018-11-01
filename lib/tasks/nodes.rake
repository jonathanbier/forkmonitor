namespace 'nodes' do :env
  desc "Update database with latest info from each node"
  task :poll => :environment do
    BitcoinClient.poll!
  end
end
