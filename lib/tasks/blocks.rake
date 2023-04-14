# frozen_string_literal: true

require 'net/http'
require 'json'

namespace 'blocks' do
  desc 'Fetch block ancestors down to [height]'
  task :fetch_ancestors, [:height] => :environment do |_action, args|
    Node.fetch_ancestors!(args.height.to_i)
  end

  desc 'Check for unwanted inflation (limit to [max=10])'
  task :check_inflation, %i[max] => :environment do |_action, args|
    InflatedBlock.check_inflation!({ max: args[:max]&.to_i })
  end

  desc 'Get chaintips for all nodes'
  task get_chaintips: :environment do |_action|
    Node.all.each do |node|
      puts "Node #{node.id}: #{node.name_with_version}:"
      begin
        Thread.report_on_exception = false
        tp node.client.getchaintips, :height, :branchlen, :status, hash: { width: 64 }
      rescue BitcoinUtil::RPC::ConnectionError
        puts 'Unreachable'
      end
      puts ''
    end
  end

  desc 'Match missing pools [n]'
  task :match_missing_pools, %i[n] => :environment do |_action, args|
    Block.match_missing_pools!(args.n.to_i)
  end

  desc 'Perform lightning related checks (limit to [max=10000])'
  task :check_lightning, %i[max] => :environment do |_action, args|
    LightningTransaction.check!({ max: args[:max] ? args[:max].to_i : 10_000 })
  end

  desc 'Process stale candidates'
  task stale_candidates: :environment do |_action, _args|
    StaleCandidate.process!
  end
end
