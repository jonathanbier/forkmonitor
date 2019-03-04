namespace 'blocks' do :env
  desc "Fetch block ancestors down to [height]"
  task :fetch_ancestors, [:height] => :environment do |action, args|
    Node.fetch_ancestors!(args.height.to_i)
  end

  desc "List version bits"
  task :version_bits => :environment do
    block = Node.where(coin: "BTC").reorder(version: :desc).first.block
    while true
      puts "#{ block.height }: %.32b" % block.version
      break unless block = block.parent
    end
  end
end
