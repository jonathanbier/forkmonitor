namespace 'blocks' do :env
  desc "Fetch block ancestors down to [height]"
  task :fetch_ancestors, [:height] => :environment do |action, args|
    Node.fetch_ancestors!(args.height.to_i)
  end
end
