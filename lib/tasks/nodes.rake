namespace 'nodes' do :env
  desc "Update database with latest info from each node"
  task :poll => :environment do
    Node.poll!
  end

  desc "Update database with latest info from each node, unless this happened recently"
  task :poll_unless_fresh => :environment do
    Node.poll!(unless_fresh: true)
  end

  desc "Poll nodes continuously"
  task :poll_repeat => :environment do
    Node.poll_repeat!
  end
end
