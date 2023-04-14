# frozen_string_literal: true

namespace 'nodes' do
  desc 'Update database with latest info from each node'
  task :poll, [] => :environment do |_action, _args|
    Node.poll!
  end

  desc 'Update database with latest info from each node, unless this happened recently'
  task poll_unless_fresh: :environment do |_action, _args|
    Node.poll!(unless_fresh: true)
  end

  desc 'Poll nodes continuously'
  task :poll_repeat, [] => :environment do |_action, _args|
    Node.poll_repeat!
  end

  desc 'Continuous checks that require rollbacks'
  task :rollback_checks_repeat, [] => :environment do |_action, _args|
    Node.rollback_checks_repeat!
  end

  desc 'Heavy duty continuous checks'
  task :heavy_checks_repeat, [] => :environment do |_action, _args|
    Node.heavy_checks_repeat!
  end
end
