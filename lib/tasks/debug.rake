namespace 'debug' do :env
  desc "Print basic info from each node"
  task :node_info => :environment do
    Node.all.each do |node|
      puts "#{node.name_with_version}"
      puts "Height: #{node.block.height}"
      puts "Time  : #{node.block.timestamp}"
      puts "Hash  : #{node.block.block_hash}"
      puts "Work  : #{node.block.work}"
      begin
        networkinfo = node.client.getnetworkinfo
        puts "Reachable"
      rescue Bitcoiner::Client::JSONRPCError
        puts "Unreachable"
      end
      puts ""
    end
  end
end
