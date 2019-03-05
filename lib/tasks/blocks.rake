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

  desc "Version bit alerts"
  task :version_bit_alerts, [:height] => :environment do |action, args|
    threshold = Rails.env.test? ? 2 : ENV['VERSION_BITS_THRESHOLD'].to_i || 50

    block = Node.where(coin: "BTC").reorder(version: :desc).first.block
    until_height = args.height.to_i

    versions_window = [0] * 100
    versions_window_new = [[0] * 32] * 100
    alerts = 0
    alerts_new = 0
    active_alert = false
    active_alert_new = [false] * 32
    while block.height >= until_height
      if !block.version.present?
        puts "Missing version for block #{ block.height }"
        exit(1)
      end

      versions_window.shift()
      versions_window.push(block.version)
      if versions_window.collect{|v| 1 && (v & ~0b100000000000000000000000000000)}.sum >= 50 && !active_alert
        active_alert = true
        alerts = alerts + 1
        puts "#{ block.height }: %.32b" % block.version
      end
      if active_alert && versions_window.collect{|v| 1 && (v & ~0b100000000000000000000000000000)}.sum == 0
        active_alert = false
      end

      versions_window_new.shift()
      versions_window_new.push(("%.32b" % (block.version & ~0b100000000000000000000000000000)).split("").collect{|s|s.to_i})

      versions_tally = versions_window_new.transpose.map(&:sum)
      if versions_tally.max >= threshold
        pos = versions_tally.index(versions_tally.max)
        if !active_alert_new[pos]
          active_alert_new[pos] = true
          alerts_new = alerts_new + 1
          puts "Start alert for version bit #{ 32 - pos - 1 }"
        end
      end
      active_alert_new.each_with_index do |alert, pos|
        if alert && versions_tally[pos] == 0
          puts "End alert for version bit #{ 32 - pos - 1 }"
          active_alert_new[pos] = false
        end
      end

      break unless block = block.parent
    end
    puts alerts
    puts alerts_new
  end
end
