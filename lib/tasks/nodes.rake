namespace 'nodes' do :env
  desc "Update database with latest info from each node"
  task :poll => :environment do
    BitcoinClient.nodes.each do |node|
      puts "Polling node #{node.pos} (#{node.name})..."
      node.poll!
    end
  end
end
