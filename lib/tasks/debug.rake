namespace 'debug' do :env
  desc "Print basic info from each node"
  task :node_info => :environment do
    BitcoinClient.nodes.each do |node|
      info = node.getinfo
      block = node.getblock(node.getbestblockhash)
      puts "#{node.name} #{info['version']}"
      puts "Height: #{block['height']}"
      puts "Time: #{block['time']}"
      puts "Hash: #{block['hash']}"
      puts "Work: #{block['chainwork']}"
      puts ""
    end
  end
end
