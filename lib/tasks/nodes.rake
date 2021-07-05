# frozen_string_literal: true

namespace 'nodes' do
  desc 'Update database with latest info from each node'
  task :poll, [] => :environment do |_action, args|
    Node.poll!({ coins: args.extras })
  end

  desc 'Update database with latest info from each node, unless this happened recently'
  task poll_unless_fresh: :environment do |_action, args|
    Node.poll!(unless_fresh: true, coins: args.extras)
  end

  desc 'Poll nodes continuously'
  task :poll_repeat, [] => :environment do |_action, args|
    Node.poll_repeat!({ coins: args.extras })
  end

  desc 'Continuous checks that require rollbacks'
  task :rollback_checks_repeat, [] => :environment do |_action, args|
    Node.rollback_checks_repeat!({ coins: args.extras })
  end

  desc 'Heavy duty continuous checks'
  task :heavy_checks_repeat, [] => :environment do |_action, args|
    Node.heavy_checks_repeat!({ coins: args.extras })
  end

  desc 'Continuous getblocktemplate checks'
  task :getblocktemplate_repeat, [] => :environment do |_action, args|
    Node.getblocktemplate_repeat!({ coins: args.extras })
  end
end
