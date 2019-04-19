namespace 'blocks' do :env
  desc "Fetch block ancestors down to [height]"
  task :fetch_ancestors, [:height] => :environment do |action, args|
    Node.fetch_ancestors!(args.height.to_i)
  end

  desc "Check for unwanted inflation"
  task :check_inflation => :environment do |action|
    Block.check_inflation!
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
end
