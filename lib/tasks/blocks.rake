require 'net/http'
require 'json'

namespace 'blocks' do :env
  desc "Fetch block ancestors down to [height]"
  task :fetch_ancestors, [:height] => :environment do |action, args|
    Node.fetch_ancestors!(args.height.to_i)
  end

  desc "Check for unwanted inflation for [coin] (limit to [max=10])"
  task :check_inflation, [:coin, :max] => :environment do |action, args|
    InflatedBlock.check_inflation!({coin: args.coin.downcase.to_sym, max: args[:max] ? args[:max].to_i : nil})
  end

  desc "Get chaintips for all nodes"
  task :get_chaintips => :environment do |action|
    Node.all.each do |node|
      puts "Node #{ node.id }: #{ node.name_with_version }:"
      tp node.client.getchaintips, :height, :branchlen, :status, :hash => {:width => 64}
    end
  end

  desc "Fetch known pool list"
  task :fetch_pool_names do |action|
    puts "Fetching known pool names from blockchain.com..."
    response = Net::HTTP.get(URI("https://raw.githubusercontent.com/blockchain/Blockchain-Known-Pools/master/pools.json"))
    pools = JSON.parse(response)
    pools["coinbase_tags"].sort.each do |key, value|
      puts "\"#{ key }\" => \"#{ value["name"] }\","
    end
  end

  desc "Match missing pools [coin] [n]"
  task :match_missing_pools, [:coin, :n] => :environment do |action, args|
    Block.match_missing_pools!(args.coin.downcase.to_sym, args.n.to_i)
  end

  desc "Perform lightning related checks for [coin] (limit to [max=10000])"
  task :check_lightning, [:coin, :max] => :environment do |action, args|
    LightningTransaction.check!({coin: args.coin.downcase.to_sym, max: args[:max] ? args[:max].to_i : 10000})
  end

  desc "Process stale candidates for [coin]"
  task :stale_candidates, [:coin] => :environment do |action, args|
    StaleCandidate.process!(args.coin.downcase.to_sym)
  end
end
