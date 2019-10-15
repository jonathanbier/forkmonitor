namespace 'nodes' do :env
  desc "Update database with latest info from each node"
  task :poll, [] => :environment do |action, args|
    Node.poll!({coins: args.extras})
  end

  desc "Update database with latest info from each node, unless this happened recently"
  task :poll_unless_fresh => :environment do
    Node.poll!(unless_fresh: true)
  end

  desc "Poll nodes continuously"
  task :poll_repeat, [] => :environment do |action, args|
    Node.poll_repeat!({coins: args.extras})
  end
  
  desc "Heavy duty continuous checks"
  task :heavy_checks_repeat, [] => :environment do |action, args|
    Node.heavy_checks_repeat!({coins: args.extras})
  end

end
