
namespace 'nodes' do :env
  desc "Update database with latest info from each node"
  task :poll => :environment do
    BitcoinClient.poll!
  end

  desc "Poll nodes continuously"
  task :poll_repeat => :environment do
    BitcoinClient.poll_repeat!
  end
end
