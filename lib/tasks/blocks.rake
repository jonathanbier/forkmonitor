require 'net/http'
require 'json'

namespace 'blocks' do :env
  desc "Fetch block ancestors down to [height]"
  task :fetch_ancestors, [:height] => :environment do |action, args|
    Node.fetch_ancestors!(args.height.to_i)
  end

  desc "Check for unwanted inflation for [coin]"
  task :check_inflation, [:coin] => :environment do |action, args|
    Block.check_inflation!(args.coin.downcase.to_sym)
  end

  desc "Get chaintips for all nodes"
  task :get_chaintips => :environment do |action|
    Node.all.each do |node|
      puts "Node #{ node.id }: #{ node.name_with_version }:"
      tp node.client.getchaintips, :height, :branchlen, :status, :hash => {:width => 64}
    end
  end

  desc "Investigate a fork [node_id] [chaintip]"
  task :investigate_fork, [:node,:chaintip] => :environment do |action, args|
    @node = Node.find(args.node.to_i)
    @node.investigate_chaintip(args.chaintip)
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
end
