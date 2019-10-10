class Node < ApplicationRecord
  belongs_to :block, required: false
  has_many :chaintips
  has_many :blocks_first_seen, class_name: "Block", foreign_key: "first_seen_by_id", dependent: :nullify
  has_many :invalid_blocks
  has_many :inflated_blocks
  has_many :tx_outsets
  belongs_to :mirror_block, required: false, class_name: "Block"

  default_scope { where(enabled: true) }

  scope :admin, -> { unscope(:where) }

  scope :bitcoin_core_by_version, -> { where(coin: "BTC", client_type: :core).where.not(version: nil).order(version: :desc) }
  scope :bitcoin_core_unknown_version, -> { where(coin: "BTC", client_type: :core).where(version: nil) }
  scope :bitcoin_alternative_implementations, -> { where(coin: "BTC"). where.not(client_type: :core) }

  enum client_type: [:core, :bcoin, :knots, :btcd, :libbitcoin, :abc, :sv, :bu]

  scope :testnet_by_version, -> { where(coin: "TBTC").order(version: :desc) }
  scope :bch_by_version, -> { where(coin: "BCH").order(version: :desc) }
  scope :bsv_by_version, -> { where(coin: "BSV").order(version: :desc) }

  def parse_version(v)
    return if v.nil?
    if v[0] == "v"
      digits = v[1..-1].split(".").collect{|d| d.to_i}
      padding = [0] * (4 - digits.size)
      digits.push(*padding)
      return digits[3] + digits[2] * 100 + digits[1] * 10000 + digits[0] * 1000000
    else
      return v
    end
  end

  def name_with_version
    return self.name if self.version.nil?
    v = self.sv? ? self.version  - 100000000 : self.version
    version_arr = v.to_s.rjust(8, "0").scan(/.{1,2}/).map(&:to_i)
    return "#{ self.name } #{ version_arr[3] == 0 && !self.bu? ? version_arr[0..2].join(".") : version_arr.join(".") }" + self.version_extra
  end
  
  def mirror_node?
    return mirror_rpchost.present? && mirror_rpchost != ""
  end

  def as_json(options = nil)
    fields = [:id, :unreachable_since, :ibd, :client_type, :pruned, :os, :cpu, :ram, :storage, :cve_2018_17144, :released]
    if options && options[:admin]
      fields << :id << :coin << :rpchost << :mirror_rpchost << :rpcport << :mirror_rpcport << :rpcuser << :rpcpassword << :version_extra << :name << :enabled
    end
    super({ only: fields }.merge(options || {})).merge({height: block && block.height, name_with_version: name_with_version})
  end

  def client
    if !@client
      @client = self.class.client_klass.new(self.client_type.to_sym, self.rpchost, self.rpcport, self.rpcuser, self.rpcpassword)
    end
    return @client
  end
  
  def mirror_client
    return nil if !self.mirror_rpchost || self.mirror_rpchost == ""
    if !@mirror_client
      @mirror_client = self.class.client_klass.new(self.client_type.to_sym, self.mirror_rpchost, self.mirror_rpcport, self.rpcuser, self.rpcpassword)
    end
    return @mirror_client
  end

  # Update database with latest info from this node
  def poll!
    if self.libbitcoin?
      block_height = client.getblockheight
      if block_height.nil?
        self.update unreachable_since: self.unreachable_since || DateTime.now
        return
      end
      header = client.getblockheader(block_height)
      best_block_hash = header["hash"]
      previousblockhash = header["previousblockhash"]
    elsif self.core? && self.version.present? && self.version < 100000
      begin
        info = client.getinfo
      rescue Bitcoiner::Client::JSONRPCError
        self.update unreachable_since: self.unreachable_since || DateTime.now
        return
      end
    else # Version is not known the first time
      begin
        blockchaininfo = client.getblockchaininfo
        networkinfo = client.getnetworkinfo
      rescue Bitcoiner::Client::JSONRPCError
        # Try getinfo for ancient nodes:
        begin
          info = client.getinfo
        rescue Bitcoiner::Client::JSONRPCError
          self.update unreachable_since: self.unreachable_since || DateTime.now
          return
        end
      end
    end

    if networkinfo.present?
      self.update(version: parse_version(networkinfo["version"]), peer_count: networkinfo["connections"])
    elsif info.present?
      self.update(version: parse_version(info["version"]), peer_count: info["connections"])
    end

    if blockchaininfo.present?
      if blockchaininfo["initialblockdownload"].present?
        ibd = blockchaininfo["initialblockdownload"]
      elsif blockchaininfo["verificationprogress"].present?
        ibd = blockchaininfo["verificationprogress"] < 0.99
      elsif self.coin == "BTC"
        ibd = info["blocks"] < Block.where(coin: :btc).maximum(:height) - 10
      end
      self.update ibd: ibd
    elsif info.present?
      # getinfo for v0.8.6 doesn't contain initialblockdownload boolean or verificationprogress.
      # As long as we also poll newer nodes, we can infer IBD status from how far behind it is.
      self.update ibd: info["blocks"] < Block.where(coin: :btc).maximum(:height) - 10
    end

    if blockchaininfo.present?
      best_block_hash = blockchaininfo["bestblockhash"]
    elsif info.present?
      best_block_hash = client.getblockhash(info["blocks"])
    end

    block = self.ibd ? nil : Block.find_or_create_block_and_ancestors!(best_block_hash, self)

    self.update block: block, unreachable_since: nil    
  end
  
  # Get most recent block height from mirror node
  def poll_mirror!
    return unless mirror_node?
    return unless self.core?
    puts "Polling mirror node..." unless Rails.env.test?
    begin
      blockchaininfo = mirror_client.getblockchaininfo
    rescue Bitcoiner::Client::JSONRPCError
      # Ignore failure
      return
    end
    best_block_hash = blockchaininfo["bestblockhash"]
    ibd = blockchaininfo["initialblockdownload"]
    block = ibd ? nil : Block.find_or_create_block_and_ancestors!(best_block_hash, self)
    self.update mirror_block: block
  end

  # getchaintips returns all known chaintips for a node, which can be:
  # * active: the current chaintip, added to our database with poll!
  # * valid-fork: valid chain, but not the most proof-of-work
  # * valid-headers: potentially valid chain, but not fully checked due to insufficient proof-of-work
  # * headers-only: same as valid-header, but even less checking done
  # * invalid: checked and found invalid, we want to make sure other nodes don't follow this, because:
  #   1) the other nodes haven't seen it all; or
  #   2) the other nodes did see it and also consider it invalid; or
  #   3) the other nodes haven't bothered to check because it doesn't have enough proof-of-work

  # We check all invalid chaintips against the database, to see if at any point in time
  # any of our other nodes saw this block, found it to have enough proof of work
  # and considered it valid. This can normally happen under two circumstances:
  # 1. the node is unaware of a soft-fork and initially accepts a block that newer
  #    nodes reject
  # 2. the node has a consensus bug
  def check_chaintips!
    if self.unreachable_since || self.ibd || self.block.nil?
      # Remove cached chaintips from db and return nil if node is unreachbale or in IBD:
      Chaintip.where(node: self).destroy_all
      return nil
    else
      # Delete existing chaintip entries, except the active one (which might be unchanged):
      Chaintip.where(node: self).where.not(status: "active").destroy_all

      # libbitcoin, btcd and older Bitcoin Core versions don't implement getchaintips, so we mock it:
      if self.client_type.to_sym == :libbitcoin ||
         self.client_type.to_sym == :btcd ||
         (self.client_type.to_sym == :core && self.version.present? && self.version < 100000)

        Chaintip.process_active!(self, block)
        return nil
      end
    end

    begin
      chaintips = client.getchaintips
    rescue Bitcoiner::Client::JSONRPCError
      # Assuming this node doesn't implement it
      return nil
    end
    return Chaintip.process_getchaintips(chaintips, self)
  end

  # Should be run after polling all nodes, otherwise it may find false positives
  def check_if_behind!(node)
    # Return nil if other node is in IBD:
    return nil if node.ibd

    # Return nil if this node is in IBD:
    return nil if self.ibd

    # Return nil if this node has no peers:
    return nil if self.peer_count == 0

    # Return nil if either node is unreachble:
    return nil if self.unreachable_since || node.unreachable_since

    behind = nil
    lag_entry = Lag.find_by(node_a: self, node_b: node)

    return nil if self.block.nil? || node.block.nil?

    # Sometimes the work field is missing:
    return nil if self.block.work.nil? || node.block.work.nil?

    # Not behind if at the same block
    if self.block == node.block
      behind = false
    # Compare work:
    elsif self.block.work < node.block.work
      behind = true
    end

    # Allow 1 block extra for 0.10.3 node:
    return nil if self.core? && self.version < 110000 && self.block.height > node.block.height - 2

    # Allow 1 block extra for btcd node:
    return nil if self.btcd? && self.block.height > node.block.height - 2

    # Remove entry if no longer behind
    if lag_entry && !behind
      lag_entry.destroy
      return nil
    end

    # Store when we first discover the lag:
    if !lag_entry && behind
      lag_entry = Lag.create(node_a: self, node_b: node)
    end

    # Return false if behind but still in grace period:
    return false if lag_entry && ((Time.now - lag_entry.created_at) < (ENV['LAG_GRACE_PERIOD'] || 1 * 60).to_i)

    # Send email after grace period
    if lag_entry && !lag_entry.notified_at
      lag_entry.update notified_at: Time.now
      User.all.each do |user|
        UserMailer.with(user: user, lag: lag_entry).lag_email.deliver
      end
    end


    return lag_entry
  end

  def check_versionbits!
    return nil if self.ibd
    self.reload # Block parent links may be stale otherwise

    threshold = Rails.env.test? ? 2 : ENV['VERSION_BITS_THRESHOLD'].to_i || 50

    block = self.block
    return nil if block.nil?

    until_height = block.height - (VersionBit::WINDOW - 1)

    versions_window = []

    while block.height >= until_height
      if !block.version.present?
        puts "Missing version for block #{ block.height }"
        exit(1)
      end

      versions_window.push(block.version_bits)
      break unless block = block.parent
    end

    return nil if versions_window.length != VersionBit::WINDOW # Less than 100 blocks or missing parent info

    versions_tally = versions_window.transpose.map(&:sum)
    throw "Unexpected versions_tally = #{ versions_tally.length } != 29"  if versions_tally.length != 29
    current_alerts = VersionBit.where(deactivate: nil).map{ |vb| [vb.bit, vb] }.to_h
    versions_tally.each_with_index do |tally, bit|
      if tally >= threshold
        if current_alerts[bit].nil?
          puts "Bit #{ bit } exceeds threshold" unless Rails.env.test?
          current_alerts[bit] = VersionBit.create(bit: bit, activate: self.block)
        end
      elsif tally == 0
        current_alert = current_alerts[bit]
        if current_alert.present?
          puts "Turn off alert for bit #{ bit }" unless Rails.env.test?
          current_alert.update deactivate: self.block
        end
      end

      # Send email
      current_alert = current_alerts[bit]
      if current_alert && !current_alert.deactivate && !current_alert.notified_at
        User.all.each do |user|
          UserMailer.with(user: user, bit: bit, tally: tally, window: VersionBit::WINDOW, block: self.block).version_bits_email.deliver
        end
        current_alert.update notified_at: Time.now
      end
    end
  end

  def investigate_chaintip(block_hash)
    # Find chaintip:
    chaintips = client.getchaintips
    matches = chaintips.select {|tip| tip["hash"] == block_hash }
    throw "Chaintip #{ block_hash } not found on node #{id} (#{name_with_version})" if matches.empty?
    chaintip = matches.first
    throw "Chaintip is not a valid-fork" unless chaintip["status"] == "valid-fork"
    fork_len = chaintip["branchlen"]
    header = client.getblockheader(block_hash)
    fork_max_height = header["height"]

    # Collect all transaction ids in fork:
    fork_txs = []
    fork_len.times do
      header = client.getblockheader(block_hash)
      puts "Processing fork block at height #{ header["height"] }"
      block = client.getblock(block_hash, 1)
      fork_txs.concat block["tx"]
      block_hash = header["previousblockhash"]
    end

    # Collect all transaction ids in main chain up to same height
    block_hash = client.getblockhash(fork_max_height)
    main_txs = []
    fork_len.times do
      header = client.getblockheader(block_hash)
      puts "Processing main chain block at height #{ header["height"] }"
      block = client.getblock(block_hash, 1)
      main_txs.concat block["tx"]
      block_hash = header["previousblockhash"]
    end

    # Collect all transaction ids in main chain up to tip
    block_hash = client.getbestblockhash
    main_tip_txs = []
    while true do
      header = client.getblockheader(block_hash)
      puts "Processing main chain block at height #{ header["height"] }"
      block = client.getblock(block_hash, 1)
      main_tip_txs.concat block["tx"]
      block_hash = header["previousblockhash"]
      break if header["height"] == fork_max_height + 1
    end

    puts "Main chain transactions            : #{ main_txs.size }"
    puts "Fork transactions                  : #{ fork_txs.size }"
    puts "Overlap (same # blocks)            : #{ (main_txs & fork_txs).size }"
    puts "Overlap at tip                     : #{ ((main_txs + main_tip_txs) & fork_txs).size }"
    puts "Unique txs main chain (ex coinbase): #{ ((main_txs + main_tip_txs) - fork_txs).size - fork_len }"
    puts "Unique txs fork chain (ex coinbase): #{ (fork_txs - (main_txs + main_tip_txs)).size - fork_len }"
  end

  def get_pool_for_block!(block_hash, block_info = nil)
    return nil unless self.core? || self.abc? || self.sv?
    block_info = block_info || self.client.getblock(block_hash)
    tx_id = block_info["tx"].first
    if self.core? && self.version && self.version >= 160000
      coinbase = self.client.getrawtransaction(tx_id, true, block_hash)
    else
      coinbase = self.client.getrawtransaction(tx_id, true)
    end
    return Block.pool_from_coinbase_tx(coinbase)
  end

  def self.poll!(options = {})
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BTC") 
      bitcoin_core_nodes = self.bitcoin_core_by_version
      bitcoin_core_nodes.each do |node|
        next if options[:unless_fresh] && node.updated_at > 5.minutes.ago
        puts "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..." unless Rails.env.test?
        node.poll!
      end

      self.bitcoin_core_unknown_version.each do |node|
        next if options[:unless_fresh] && node.updated_at > 5.minutes.ago
        puts "Polling #{ node.coin } node #{node.id} (unknown verison)..." unless Rails.env.test?
        node.poll!
      end

      bitcoin_alternative_implementations.each do |node|
        next if options[:unless_fresh] && node.updated_at > 5.minutes.ago
        # Skip libbitcoin in repeat poll, due to ZMQ socket errors
        next if options[:repeat] && node.client_type.to_sym == :libbitcoin
        puts "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..." unless Rails.env.test?
        node.poll!
      end
    end
    
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("TBTC") 
      self.testnet_by_version.each do |node|
        next if options[:unless_fresh] && node.updated_at > 5.minutes.ago
        puts "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..." unless Rails.env.test?
        node.poll!
      end
    end

    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BCH") 
      self.bch_by_version.each do |node|
        next if options[:unless_fresh] && node.updated_at > 5.minutes.ago
        puts "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..." unless Rails.env.test?
        node.poll!
      end
    end
    
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BSV") 
      self.bsv_by_version.each do |node|
        next if options[:unless_fresh] && node.updated_at > 5.minutes.ago
        puts "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..." unless Rails.env.test?
        node.poll!
      end
    end

    self.check_laggards!(options)
    self.check_chaintips!(options)
    
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BTC") 
      bitcoin_core_nodes.first.check_versionbits!
    end
  end

  def self.poll_repeat!(coins)
    # Trap ^C
    Signal.trap("INT") {
      puts "\nShutting down gracefully..."
      exit
    }

    # Trap `Kill `
    Signal.trap("TERM") {
      puts "\nShutting down gracefully..."
      exit
    }

    while true
      sleep 5 unless Rails.env.test?

      self.poll!(repeat: true, coins: coins)

      if Rails.env.test?
        break
      else
        sleep 0.5
      end
    end
  end
  
  def self.heavy_checks_repeat!(coins)
    # Trap ^C
    Signal.trap("INT") {
      puts "\nShutting down gracefully..."
      exit
    }

    # Trap `Kill `
    Signal.trap("TERM") {
      puts "\nShutting down gracefully..."
      exit
    }

    while true
      coins.each do |coin| 
        Block.check_inflation!(coin.downcase.to_sym)        
      end
      
      if Rails.env.test?
        break
      else
        sleep 0.5
      end

    end
  end

  def self.check_chaintips!(options)
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BTC") 
      self.bitcoin_core_by_version.each do |node|
        node.reload
        node.check_chaintips!
      end
    end
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BTC") 
      self.bitcoin_alternative_implementations.each do |node|
        node.reload
        node.check_chaintips!
      end
    end
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("TBTC") 
      self.testnet_by_version.each do |node|
        node.reload
        node.check_chaintips!
      end
    end
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BCH")
      self.bch_by_version.each do |node|
        node.reload
        node.check_chaintips!
      end
    end
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BSV")
      self.bsv_by_version.each do |node|
        node.reload
        node.check_chaintips!
      end
    end
      
    # Look for potential stale blocks, i.e. more than one block at the same height
    for coin in [:btc, :tbtc, :bch, :bsv] do
      next if options[:coins] && !options[:coins].empty? && !options[:coins].include?(coin.to_s.upcase)
      tip_height = Block.where(coin: coin).maximum(:height)
      next if tip_height.nil?
      Block.select(:height).where(coin: coin).where("height > ?", tip_height - 100).group(:height).having('count(height) > 1').each do |block|
        @stale_candidate = StaleCandidate.find_or_create_by(coin: coin, height: block.height)
        if @stale_candidate.notified_at.nil?
          User.all.each do |user|
            UserMailer.with(user: user, stale_candidate: @stale_candidate).stale_candidate_email.deliver
          end
          @stale_candidate.update notified_at: Time.now
          Subscription.blast("stale-candidate-#{ @stale_candidate.id }",
                             "#{ @stale_candidate.coin.upcase } stale candidate",
                             "At height #{ @stale_candidate.height }"
          )
        end
      end
    end
  end

  def self.check_laggards!(options = {})
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BTC") 
      core_nodes = self.bitcoin_core_by_version
      core_nodes.drop(1).each do |node|
        lag  = node.check_if_behind!(core_nodes.first)
        puts "Check if #{ node.name_with_version } is behind #{ core_nodes.first.name_with_version }... #{ lag.present? }" unless Rails.env.test?
      end

      self.bitcoin_alternative_implementations.each do |node|
        next if options[:repeat] && node.client_type.to_sym == :libbitcoin
        lag  = node.check_if_behind!(core_nodes.first)
        puts "Check if #{ node.name_with_version } is behind #{ core_nodes.first.name_with_version }... #{ lag.present? }" unless Rails.env.test?
      end
    end
  end

  def self.fetch_ancestors!(until_height)
    node = Node.bitcoin_core_by_version.first
    throw "Node in Initial Blockchain Download" if node.ibd
    node.block.find_ancestors!(node, until_height)
  end

  private

  def self.client_klass
    Rails.env.test? ? BitcoinClientMock : BitcoinClient
  end

end
