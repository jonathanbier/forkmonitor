namespace 'nodes' do :env
  desc "Update database with latest info from each node"
  task :poll => :environment do
    Node.poll!
  end

  desc "Poll nodes continuously"
  task :poll_repeat => :environment do
    Node.poll_repeat!
  end
end
