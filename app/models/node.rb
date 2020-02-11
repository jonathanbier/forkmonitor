class Node < ApplicationRecord
  SUPPORTED_COINS=[:btc, :tbtc, :bch, :bsv]

  after_commit :expire_cache

  class Error < StandardError; end
  class InvalidCoinError < Error; end
  class NoTxIndexError < Error; end
  class TxNotFoundError < Error; end

  belongs_to :block, required: false
  has_many :chaintips, dependent: :destroy
  has_many :blocks_first_seen, class_name: "Block", foreign_key: "first_seen_by_id", dependent: :nullify
  has_many :invalid_blocks, :dependent => :restrict_with_exception
  has_many :inflated_blocks, :dependent => :restrict_with_exception
  has_many :lag_a, class_name: "Lag", foreign_key: "node_a_id", dependent: :destroy
  has_many :lag_b, class_name: "Lag", foreign_key: "node_b_id", dependent: :destroy
  has_many :tx_outsets, dependent: :destroy
  belongs_to :mirror_block, required: false, class_name: "Block"

  before_save :clear_chaintips, if: :will_save_change_to_enabled?

  scope :bitcoin_core_by_version, -> { where(enabled: true, coin: "BTC", client_type: :core).where.not(version: nil).order(version: :desc) }
  scope :bitcoin_core_unknown_version, -> { where(enabled: true, coin: "BTC", client_type: :core).where(version: nil) }
  scope :bitcoin_alternative_implementations, ->{ where(enabled: true, coin: "BTC"). where.not(client_type: :core) }

  enum client_type: [:core, :bcoin, :knots, :btcd, :libbitcoin, :abc, :sv, :bu]

  scope :testnet_by_version, -> { where(enabled: true, coin: "TBTC").order(version: :desc) }
  scope :bch_by_version, -> { where(enabled: true, coin: "BCH").order(version: :desc) }
  scope :bsv_by_version, -> { where(enabled: true, coin: "BSV").order(version: :desc) }

  def self.coin_by_version(coin)
    where(enabled: true, coin: coin.to_s.upcase).order(version: :desc)
  end

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
    name = "#{ self.name }"
    if self.version.nil?
      if self.version_extra.present?
        # Allow admin to hardcode version
        name += " #{ self.version_extra }"
      end
      return name
    end
    v = self.sv? ? self.version  - 100000000 : self.version
    version_arr = v.to_s.rjust(8, "0").scan(/.{1,2}/).map(&:to_i)
    return name + " #{ version_arr[3] == 0 && !self.bu? ? version_arr[0..2].join(".") : version_arr.join(".") }" + self.version_extra
  end

  def mirror_node?
    return mirror_rpchost.present? && mirror_rpchost != ""
  end

  def as_json(options = nil)
    fields = [:id, :unreachable_since, :ibd, :client_type, :pruned, :txindex, :os, :cpu, :ram, :storage, :cve_2018_17144, :released]
    if options && options[:admin]
      fields << :id << :coin << :rpchost << :mirror_rpchost << :rpcport << :mirror_rpcport << :rpcuser << :rpcpassword << :version_extra << :name << :enabled
    end
    super({ only: fields }.merge(options || {})).merge({
      height: block && block.height,
      name_with_version: name_with_version,
      tx_outset: self.tx_outset,
      has_mirror_node: self.mirror_rpchost.present?
    })
  end

  def client
    if !@client
      if self.python
        @client = BitcoinClientPython.new(self.id, self.name_with_version, self.client_type.to_sym)
      else
        @client = self.class.client_klass.new(self.id, self.name_with_version, self.client_type.to_sym, self.rpchost, self.rpcport, self.rpcuser, self.rpcpassword)
      end
    end
    return @client
  end

  def mirror_client
    return nil if !self.mirror_rpchost || self.mirror_rpchost == ""
    if !@mirror_client
      @mirror_client = self.class.client_klass.new(self.id, self.name_with_version, self.client_type.to_sym, self.mirror_rpchost, self.mirror_rpcport, self.rpcuser, self.rpcpassword)
    end
    return @mirror_client
  end

  def tx_outset
    self.tx_outsets.find_by(block: self.block)
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
      rescue BitcoinClient::Error
        self.update unreachable_since: self.unreachable_since || DateTime.now
        return
      end
    else # Version is not known the first time
      begin
        blockchaininfo = client.getblockchaininfo
        networkinfo = client.getnetworkinfo
      rescue BitcoinClient::Error
        # Try getinfo for ancient nodes:
        begin
          info = client.getinfo
        rescue BitcoinClient::Error
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

    if self.libbitcoin?
      ibd = block_height < 560176
    elsif blockchaininfo.present?
      if blockchaininfo["initialblockdownload"].present?
        ibd = blockchaininfo["initialblockdownload"]
      elsif blockchaininfo["verificationprogress"].present?
        ibd = blockchaininfo["verificationprogress"] < 0.99
      elsif self.coin == "BTC"
        ibd = info["blocks"] < Block.where(coin: :btc).maximum(:height) - 10
      end
    end
    self.update ibd: ibd

    if blockchaininfo.present?
      best_block_hash = blockchaininfo["bestblockhash"]
    elsif info.present?
      best_block_hash = client.getblockhash(info["blocks"])
    end

    block = self.ibd ? nil : Block.find_or_create_block_and_ancestors!(best_block_hash, self, false)

    self.update block: block, unreachable_since: nil
  end

  # Get most recent block height from mirror node
  def poll_mirror!
    return unless mirror_node?
    return unless self.core?
    puts "Polling mirror node..." unless Rails.env.test?
    begin
      blockchaininfo = mirror_client.getblockchaininfo
    rescue BitcoinClient::Error
      # Ignore failure
      return
    end
    best_block_hash = blockchaininfo["bestblockhash"]
    ibd = blockchaininfo["initialblockdownload"]
    block = ibd ? nil : Block.find_or_create_block_and_ancestors!(best_block_hash, self, true)
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
    rescue BitcoinClient::Error
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

    # Allow 1 block extra for 0.16 nodes and older:
    return nil if self.core? && self.version < 169999 && self.block.height > node.block.height - 2

    # Allow 1 block extra for btcd and Knots nodes:
    return nil if (self.btcd? || self.knots?) && self.block.height > node.block.height - 2

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

    if lag_entry
      # Mark as ready to publish on RSS
      lag_entry.update publish: true

      # Send email after grace period
      if !lag_entry.notified_at
        lag_entry.update notified_at: Time.now
        User.all.each do |user|
          UserMailer.with(user: user, lag: lag_entry).lag_email.deliver
        end
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

  def get_pool_for_block!(block_hash, use_mirror, block_info = nil)
    return nil unless self.core? || self.abc? || self.sv?
    client = use_mirror ? self.mirror_client : self.client
    begin
      block_info = block_info || client.getblock(block_hash)
    rescue BitcoinClient::Error
      puts "Unable to fetch block #{ block_hash } from #{ self.name_with_version } while looking for pool name"
      return nil
    end
    tx_id = block_info["tx"].first
    begin
      coinbase = getrawtransaction(tx_id, true, block_hash)
      return Block.pool_from_coinbase_tx(coinbase)
    rescue TxNotFoundError
      return nil
    end
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

  def self.poll_repeat!(options = {})
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

      self.poll!(options.merge({repeat: true}))

      if Rails.env.test?
        break
      else
        sleep 0.5
      end
    end
  end

  # Returns false if node is not reachable. Returns nil if current mirror_block is missing.
  def restore_mirror
    begin
      mirror_client.setnetworkactive(true)
    rescue BitcoinClient::Error
      return false
    end
    return if mirror_block.nil?
    # Reconsider all invalid chaintips above the currently active one:
    chaintips = mirror_client.getchaintips
    active_chaintip = chaintips.find { |t| t["status"] == "active" }
    throw "#{ coin } mirror node #{  } does not have an active chaintip" if active_chaintip.nil?
    chaintips.select { |t| t["status"] == "invalid" && t["height"] >= active_chaintip["height"] }.each do |t|
      mirror_client.reconsiderblock(t["hash"])
    end
  end

  def get_mirror_active_tip
    mirror_client.getchaintips.find { |t|
      t["status"] == "active"
    }
  end

  def getrawtransaction(tx_id, verbose = false, block_hash = nil)
    begin
      if self.core? && self.version && self.version >= 160000
        return client.getrawtransaction(tx_id, verbose, block_hash)
      else
        return client.getrawtransaction(tx_id, verbose)
      end
    rescue BitcoinClient::Error
      # TODO: check error more precisely
      raise TxNotFoundError, "Transaction #{ tx_id } #{ block_hash.present? ? "in block #{ block_hash }" : "" } not found on node #{id} (#{name_with_version})"
    end
  end

  def self.heavy_checks_repeat!(options)
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
      options[:coins].each do |coin|
        InflatedBlock.check_inflation!({coin: coin.downcase.to_sym, max: 1000})
        LightningTransaction.check!({coin: coin.downcase.to_sym, max: 1000}) if coin == "BTC"
        LightningTransaction.check_public_channels! if coin == "BTC"
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
      self.bitcoin_alternative_implementations.each do |node|
        node.reload
        node.check_chaintips!
      end
      Node.prune_empty_chaintips!(:btc)
    end
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("TBTC")
      self.testnet_by_version.each do |node|
        node.reload
        node.check_chaintips!
      end
      Node.prune_empty_chaintips!(:tbtc)
    end
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BCH")
      self.bch_by_version.each do |node|
        node.reload
        node.check_chaintips!
      end
      Node.prune_empty_chaintips!(:bch)
    end
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BSV")
      self.bsv_by_version.each do |node|
        node.reload
        node.check_chaintips!
      end
      Node.prune_empty_chaintips!(:bsv)
    end

    # Look for potential stale blocks, i.e. more than one block at the same height
    for coin in SUPPORTED_COINS do
      next if options[:coins] && !options[:coins].empty? && !options[:coins].include?(coin.to_s.upcase)
      tip_height = Block.where(coin: coin).maximum(:height)
      next if tip_height.nil?
      Block.select(:height).where(coin: coin).where("height > ?", tip_height - 100).group(:height).having('count(height) > 1').each do |block|
        @stale_candidate = StaleCandidate.find_or_create_by(coin: coin, height: block.height)
        if @stale_candidate.notified_at.nil?
          User.all.each do |user|
            if ![:tbtc].include?(coin) # skip email notification for testnet
              UserMailer.with(user: user, stale_candidate: @stale_candidate).stale_candidate_email.deliver
            end
          end
          @stale_candidate.update notified_at: Time.now
          if ![:tbtc].include?(coin) # skip push notification for testnet
            Subscription.blast("stale-candidate-#{ @stale_candidate.id }",
                               "#{ @stale_candidate.coin.upcase } stale candidate",
                               "At height #{ @stale_candidate.height }"
            )
          end
        end
      end
    end
  end

  # Sometimes an empty chaintip is left over
  def self.prune_empty_chaintips!(coin)
    Chaintip.includes(:node).where(coin: coin).where(nodes: { id: nil }).destroy_all
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
    node.block.find_ancestors!(node, false, until_height)
  end

  def self.first_with_txindex(coin, client_type = :core)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    node = Node.where("coin = ?", coin.upcase).where(txindex: true, client_type: client_type).first or raise NoTxIndexError
  end

  def self.getrawtransaction(tx_id, coin, verbose = false, block_hash = nil)
    first_with_txindex(coin).getrawtransaction(tx_id, verbose, block_hash)
  end

  private

  def self.client_klass
    Rails.env.test? ? BitcoinClientMock : BitcoinClient
  end

  def self.last_updated_cached(coin)
      Rails.cache.fetch("Node.last_updated(#{ coin })") { where(coin: coin).order(updated_at: :desc).first }
  end

  def expire_cache
      Rails.cache.delete("Node.last_updated(#{self.coin})")
  end

  def clear_chaintips
    return if self.enabled
    Chaintip.where(node: self).destroy_all
  end

end
