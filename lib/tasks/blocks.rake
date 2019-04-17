namespace 'blocks' do :env
  desc "Fetch block ancestors down to [height]"
  task :fetch_ancestors, [:height] => :environment do |action, args|
    Node.fetch_ancestors!(args.height.to_i)
  end

  desc "Check for unwanted inflation"
  task :check_inflation => :environment do |action|
    Block.check_inflation!
  end
end
