class Node < ApplicationRecord
  include ::TxIdConcern

  SUPPORTED_COINS=[:btc, :tbtc, :bch]

  # BSV support has been removed, but enums are stored as integer in the database.
  enum coin: [:btc, :bch, :bsv, :tbtc]

  nilify_blanks only: [:mirror_rpchost]

  after_commit :expire_cache

  class Error < StandardError; end
  class InvalidCoinError < Error; end
  class NoTxIndexError < Error; end
  class TxNotFoundError < Error; end
  class ConnectionError < Error; end
  class PartialFileError < Error; end
  class BlockPrunedError < Error; end
  class BlockNotFoundError < Error; end
  class MethodNotFoundError < Error; end
  class NoMatchingNodeError < Error; end
  class TimeOutError < Error; end

  belongs_to :block, required: false
  has_many :chaintips, dependent: :destroy
  has_many :blocks_first_seen, class_name: "Block", foreign_key: "first_seen_by_id", dependent: :nullify
  has_many :invalid_blocks, :dependent => :restrict_with_exception
  has_many :inflated_blocks, :dependent => :restrict_with_exception
  has_many :lag_a, class_name: "Lag", foreign_key: "node_a_id", dependent: :destroy
  has_many :lag_b, class_name: "Lag", foreign_key: "node_b_id", dependent: :destroy
  has_many :tx_outsets, dependent: :destroy
  belongs_to :mirror_block, required: false, class_name: "Block"
  has_one :active_chaintip, -> { where(status: "active") }, class_name: "Chaintip"
  has_many :softforks

  before_save :clear_chaintips, if: :will_save_change_to_enabled?
  before_destroy :clear_references

  scope :bitcoin_core_by_version, -> { where(enabled: true, special: false, coin: :btc, client_type: :core).where.not(version: nil).order(version: :desc) }
  scope :bitcoin_core_unknown_version, -> { where(enabled: true, special: false, coin: :btc, client_type: :core).where(version: nil) }
  scope :bitcoin_alternative_implementations, ->{ where(enabled: true, special: false, coin: :btc). where.not(client_type: :core) }

  # Enum is stored as an integer, so do not remove entries from this list:
  enum client_type: [:core, :bcoin, :knots, :btcd, :libbitcoin, :abc, :sv, :bu, :omni, :blockcore]

  scope :testnet_by_version, -> { where(enabled: true, special: false, coin: :tbtc).order(version: :desc) }
  scope :bch_by_version, -> { where(enabled: true, special: false, coin: :bch).order(version: :desc) }

  def self.coin_by_version(coin)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    where(enabled: true, special: false, coin: coin).order(version: :desc)
  end

  def self.with_mirror(coin)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    where(enabled: true, special: false, coin: coin, client_type: :core).where.not(mirror_rpchost: nil).order(version: :desc)
  end

  def parse_version(v)
    return if v.nil?
    if v.is_a?(String) && v.split(".").count >= 3
      digits = v.split(".").collect{|d| d.to_i}
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
    version_arr = self.version.to_s.rjust(8, "0").scan(/.{1,2}/).map(&:to_i)
    return name + " #{ version_arr[3] == 0 && !self.bu? ? version_arr[0..2].join(".") : version_arr.join(".") }" + self.version_extra
  end

  def as_json(options = nil)
    fields = [
      :id,
      :unreachable_since,
      :mirror_unreachable_since,
      :ibd,
      :client_type,
      :pruned,
      :txindex,
      :os,
      :cpu,
      :ram,
      :storage,
      :cve_2018_17144,
      :released,
      :sync_height,
      :link,
      :link_text,
      :mempool_count,
      :mempool_bytes,
      :mempool_max,
      :mirror_ibd,
      :special,
      :to_destroy,
      :getblocktemplate
    ]
    if options && options[:admin]
      fields << :id << :coin << :rpchost << :mirror_rpchost << :rpcport << :mirror_rpcport << :rpcuser << :rpcpassword << :version_extra << :name << :enabled
    end
    super({ only: fields }.merge(options || {})).merge({
      height: active_chaintip && active_chaintip.block.height,
      name_with_version: name_with_version,
      tx_outset: self.tx_outset,
      last_tx_outset: self.tx_outsets.last,
      has_mirror_node: self.mirror_rpchost.present?,
      bip9_softforks: self.softforks.where(fork_type: :bip9),
      bip8_softforks: self.softforks.where(fork_type: :bip8)
    })
  end

  def client
    if !@client
      if self.python
        @client = BitcoinClientPython.new(self.id, self.name_with_version, self.coin.to_sym, self.client_type.to_sym, self.version)
      else
        @client = self.class.client_klass.new(self.id, self.name_with_version, self.coin.to_sym, self.client_type.to_sym, self.version, self.rpchost, self.rpcport, self.rpcuser, self.rpcpassword)
      end
    end
    return @client
  end

  def mirror_client
    return nil if !self.mirror_rpchost
    if !@mirror_client
      if self.python
        @mirror_client = BitcoinClientPython.new(self.id, self.name_with_version, self.coin.to_sym, self.client_type.to_sym, self.version)
      else
        @mirror_client = self.class.client_klass.new(self.id, self.name_with_version, self.coin.to_sym, self.client_type.to_sym, self.version, self.mirror_rpchost, self.mirror_rpcport, self.rpcuser, self.rpcpassword)
      end
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
    elsif self.btcd?
      begin
        blockchaininfo = client.getblockchaininfo
        info = client.getinfo
      rescue BitcoinClient::Error
        self.update unreachable_since: self.unreachable_since || DateTime.now
        return
      end
    elsif self.core? && self.version.present? && self.version < 100000
      begin
        info = client.getinfo
      rescue BitcoinClient::Error
        self.update unreachable_since: self.unreachable_since || DateTime.now
        return
      end
    elsif self.core? && self.version.present?
      begin
        blockchaininfo = client.getblockchaininfo
        networkinfo = client.getnetworkinfo
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
      ibd = block_height < 631885
    elsif blockchaininfo.present?
      block_height = blockchaininfo["blocks"]
      if blockchaininfo.key?("initialblockdownload")
        ibd = blockchaininfo["initialblockdownload"]
      elsif blockchaininfo.key?("verificationprogress")
        ibd = blockchaininfo["verificationprogress"] < 0.9999
      elsif self.btc?
        ibd = info["blocks"] < Block.where(coin: :btc).maximum(:height) - 10
      end
    end
    self.update ibd: ibd, sync_height: ibd ? block_height : nil

    if blockchaininfo.present?
      best_block_hash = blockchaininfo["bestblockhash"]
      Softfork.process(self, blockchaininfo) if self.btc? && (self.core? || self.knots?)
    elsif info.present?
      best_block_hash = client.getblockhash(info["blocks"])
    end

    mempool_bytes = nil
    mempool_count = nil
    mempool_max = nil
    unless self.libbitcoin?
      mempool_info = client.getmempoolinfo
      mempool_bytes = mempool_info["bytes"]
      mempool_count = mempool_info["size"]
      mempool_max = mempool_info["maxmempool"]
    end

    raise "Best block hash unexpectedly nil" unless best_block_hash.present?
    # Mark node as reachable (if needed) before trying to fetch additional info
    # such as the coinbase message.
    if self.unreachable_since
      self.update polled_at: Time.now, unreachable_since: nil
    end

    block = self.ibd ? nil : Block.find_or_create_block_and_ancestors!(best_block_hash, self, false, true)

    self.update(
      polled_at: Time.now,
      unreachable_since: nil,
      block: block,
      mempool_bytes: mempool_bytes,
      mempool_count: mempool_count,
      mempool_max: mempool_max
    )
  end

  # Get most recent block height from mirror node
  def poll_mirror!
    return if mirror_rpchost.nil?
    return unless self.core?
    Rails.logger.debug "Polling mirror node..."
    begin
      blockchaininfo = mirror_client.getblockchaininfo
    rescue BitcoinClient::Error
      Rails.logger.debug "Failed to poll mirror node..."
      # Ignore failure
      return
    end
    best_block_hash = blockchaininfo["bestblockhash"]
    ibd = blockchaininfo["initialblockdownload"]
    block = ibd ? nil : Block.find_or_create_block_and_ancestors!(best_block_hash, self, true, nil)
    self.update mirror_block: block, last_polled_mirror_at: Time.now, mirror_ibd: ibd
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

    return nil if self.active_chaintip.nil? || node.active_chaintip.nil?

    # Sometimes the work field is missing:
    return nil if self.active_chaintip.block.work.nil? || node.active_chaintip.block.work.nil?

    # Not behind if at the same block
    if self.active_chaintip.block == node.active_chaintip.block
      behind = false
    # Compare work:
    elsif self.active_chaintip.block.work < node.active_chaintip.block.work
      behind = true
    end

    blocks_behind = node.active_chaintip.block.height - self.active_chaintip.block.height

    # Allow 1 block extra for 0.16 nodes and older:
    return nil if self.core? && self.version < 169999 && blocks_behind < 2

    # Allow 1 block extra for btcd and Knots nodes:
    return nil if (self.btcd? || self.knots?) && blocks_behind < 2

    # Allow 10 blocks extra for libbitcion nodes:
    return nil if self.libbitcoin? && blocks_behind < 10

    # Remove entry if no longer behind
    if lag_entry && !behind
      lag_entry.destroy
      return nil
    end

    if behind
      if !lag_entry
        # Store when we first discover the lag
        lag_entry = Lag.create(node_a: self, node_b: node, blocks: blocks_behind)
      else
        # Update block count, but only if it increased:
        if lag_entry.blocks < blocks_behind
          lag_entry.update blocks: blocks_behind
        end
      end
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
        Rails.logger.error "Missing version for block #{ block.height }"
        return nil
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
          Rails.logger.info "Bit #{ bit } exceeds threshold"
          current_alerts[bit] = VersionBit.create(bit: bit, activate: self.block)
        end
      elsif tally == 0
        current_alert = current_alerts[bit]
        if current_alert.present?
          Rails.logger.info "Turn off alert for bit #{ bit }"
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

  def getblock(block_hash, verbosity, use_mirror = false)
    throw "Specify block hash" if block_hash.nil?
    throw "Specify verbosity" if verbosity.nil?
    client = use_mirror ? self.mirror_client : self.client
    # https://github.com/bitcoin/bitcoin/blob/master/doc/release-notes/release-notes-0.15.0.md#low-level-rpc-changes
    # * argument verbosity was called "verbose" in older versions, but we use a positional argument
    # * verbose was a boolean until Bitcoin Core 0.15.0
    if core? && version <= 149999
      verbosity = verbosity > 0
    end
    begin
      client.getblock(block_hash, verbosity)
    rescue BitcoinClient::ConnectionError
      raise ConnectionError
    rescue BitcoinClient::PartialFileError
      raise PartialFileError
    rescue BitcoinClient::BlockPrunedError
      raise BlockPrunedError
    rescue BitcoinClient::BlockNotFoundError
      raise BlockNotFoundError
    rescue BitcoinClient::TimeOutError
      raise TimeOutError
    end
  end

  def getblockheader(block_hash, verbose = true, use_mirror = false)
    throw "Specify block hash" if block_hash.nil?
    client = use_mirror ? self.mirror_client : self.client
    begin
      client.getblockheader(block_hash, verbose)
    rescue BitcoinClient::ConnectionError
      raise ConnectionError
    rescue BitcoinClient::PartialFileError
      raise PartialFileError
    rescue BitcoinClient::BlockNotFoundError
      raise BlockNotFoundError
    rescue BitcoinClient::MethodNotFoundError
      raise MethodNotFoundError
    rescue BitcoinClient::TimeOutError
      raise TimeOutError
    end
  end

  def self.poll!(options = {})
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BTC")
      self.bitcoin_core_by_version.each do |node|
        next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago
        Rails.logger.debug "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..."
        node.poll!
      end

      self.bitcoin_core_unknown_version.each do |node|
        next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago
        Rails.logger.debug "Polling #{ node.coin } node #{node.id} (unknown verison)..."
        node.poll!
      end

      bitcoin_alternative_implementations.each do |node|
        next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago
        # Skip libbitcoin in repeat poll, due to ZMQ socket errors
        next if options[:repeat] && node.client_type.to_sym == :libbitcoin
        Rails.logger.debug "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..."
        node.poll!
      end

      self.check_chaintips!(:btc)
      StaleCandidate.check!(:btc)
    end

    if !options[:coins] || options[:coins].empty? || options[:coins].include?("TBTC")
      self.testnet_by_version.each do |node|
        next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago
        Rails.logger.debug "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..."
        node.poll!
      end


      self.check_chaintips!(:tbtc)
      StaleCandidate.check!(:tbtc)
    end

    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BCH")
      self.bch_by_version.each do |node|
        next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago
        Rails.logger.debug "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..."
        node.poll!
      end

      self.check_chaintips!(:bch)
      StaleCandidate.check!(:bch)
    end

    self.check_laggards!(options)

    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BTC")
      self.bitcoin_core_by_version.first.check_versionbits!
    end
  end

  def self.poll_repeat!(options = {})
    # Trap ^C
    Signal.trap("INT") {
      Rails.logger.info "\nShutting down gracefully..."
      exit
    }

    # Trap `Kill `
    Signal.trap("TERM") {
      Rails.logger.info "\nShutting down gracefully..."
      exit
    }

    while true
      Rails.logger.info "Polling #{ options[:coins].join(", ") } nodes..."
      sleep 5

      self.poll!(options.merge({repeat: true}))

      if Rails.env.test?
        break
      else
        sleep 0.5
      end
    end
  end

  def self.newest_node(coin)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    case coin
    when :btc, :tbtc
      return Node.newest(coin, :core)
    when :bch
      return Node.newest(coin, :abc)
    end
    throw "Unable to find suitable #{ coin } node in newest_node"
  end

  # Find pool name for a block. For modern nodes it uses getrawtransaction
  # with a blockhash argument, so a txindex is not required.
  # For older nodes it could process the raw block instead of using getrawtransaction,
  # but that has not been implemented.
  # Also returns array with tx ids
  def self.get_coinbase_and_tx_ids_for_block!(coin, block_hash, block_info = nil)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    node = nil
    begin
      case coin
      when :btc, :tbtc
        # getrawtransaction supports blockhash as of version 0.16, perhaps earlier too
        node = Node.first_newer_than(coin, 160000, :core)
      when :bch
        # getrawtransaction supports blockhash as of version 0.21, perhaps earlier too
        node = Node.first_newer_than(coin, 210000, :abc)
      end
    rescue Node::NoMatchingNodeError
      Rails.logger.warn "Unable to find suitable #{ coin } node in get_coinbase_and_tx_ids_for_block"
      return nil
    end
    client = node.client
    begin
      block_info = block_info || node.getblock(block_hash, 1)
    rescue Node::BlockPrunedError
      return nil
    rescue Node::BlockNotFoundError
      return nil
    rescue BitcoinClient::Error => e
      logger.error "Unable to fetch block #{ block_hash } from #{ node.name_with_version } while looking for pool name"
      return nil
    end
    return nil if block_info["height"] == 0 # Can't fetch the genesis coinbase
    return nil if block_info["tx"].nil?
    tx_id = block_info["tx"].first
    begin
      return node.getrawtransaction(tx_id, true, block_hash), block_info["tx"]
    rescue TxNotFoundError
      return nil
    end
  end

  def self.set_pool_tx_ids_fee_total_for_block!(coin, block, block_info = nil)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    coinbase, tx_ids = get_coinbase_and_tx_ids_for_block!(coin, block.block_hash, block_info)
    return if coinbase.nil? || coinbase == {}
    tx_ids.shift # skip coinbase
    block.tx_ids = hashes_to_binary(tx_ids)
    block.pool = Block.pool_from_coinbase_tx(coinbase)
    block.total_fee = (coinbase["vout"].sum { |vout| vout["value"] } * 100000000.0 - block.max_inflation) / 100000000.0
    if block.pool.nil?
      coinbase_message = Block.coinbase_message(coinbase)
      return if coinbase_message.nil?
      block.coinbase_message = coinbase_message.unpack('H*')
    end
    block.save if block.changed?
  end

  # Returns false if node is not reachable. Returns nil if current mirror_block is missing.
  def restore_mirror
    begin
      mirror_client.setnetworkactive(true)
    rescue BitcoinClient::ConnectionError, BitcoinClient::NodeInitializingError
      self.update mirror_unreachable_since: Time.now, last_polled_mirror_at: Time.now
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

  def rpc_getblocktemplate
    if self.version >= 130100
      return client.getblocktemplate({rules: ["segwit"]})
    else
      return client.getblocktemplate({rules: []})
    end
  end

  def self.rollback_checks_repeat!(options)
    # Trap ^C
    Signal.trap("INT") {
      Rails.logger.info "\nShutting down gracefully..."
      exit
    }

    # Trap `Kill `
    Signal.trap("TERM") {
      Rails.logger.info "\nShutting down gracefully..."
      exit
    }

    while true
      options[:coins].each do |coin|
        InflatedBlock.check_inflation!({coin: coin.downcase.to_sym, max: 10})
        Node.where(coin: coin.downcase.to_sym, client_type: :core).where.not(mirror_rpchost: nil).each do |node|
          Chaintip.validate_forks!(node, 50)
        end
      end

      if Rails.env.test?
        break
      else
        sleep 0.5
      end

    end
  end

  def self.heavy_checks_repeat!(options)
    # Trap ^C
    Signal.trap("INT") {
      Rails.logger.info "\nShutting down gracefully..."
      exit
    }

    # Trap `Kill `
    Signal.trap("TERM") {
      Rails.logger.info "\nShutting down gracefully..."
      exit
    }

    while true
      options[:coins].each do |coin|
        LightningTransaction.check!({coin: coin.downcase.to_sym, max: 1000}) if coin == "BTC"
        LightningTransaction.check_public_channels! if coin == "BTC"
        Block.match_missing_pools!(coin.downcase.to_sym, 3)
        Block.process_templates!(coin.downcase.to_sym)
        Block.find_missing(coin.downcase.to_sym, 40000, 20) # waits 20 seconds for blocks
        StaleCandidate.process!(coin.downcase.to_sym)
        StaleCandidate.prime_cache(coin.downcase.to_sym)
        Softfork.notify!
        Rpush.apns_feedback unless Rails.env.test?
        Rpush.push unless Rails.env.test?
        Node.destroy_if_requested(coin.downcase.to_sym)
      end

      if Rails.env.test?
        break
      else
        sleep 0.5
      end

    end
  end

  def self.getblocktemplate_repeat!(options)
    # Trap ^C
    Signal.trap("INT") {
      Rails.logger.info "\nShutting down gracefully..."
      exit
    }

    # Trap `Kill `
    Signal.trap("TERM") {
      Rails.logger.info "\nShutting down gracefully..."
      exit
    }

    @last_checked = nil

    while true
      if @last_checked.nil? || @last_checked < 20.seconds.ago
        @last_checked = Time.now
        options[:coins].each do |coin|
          Node.getblocktemplate!(coin.downcase.to_sym)
        end
      end

      if Rails.env.test?
        break
      else
        sleep 0.5
      end

    end
  end

  def self.check_chaintips!(coin)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    case coin
    when :btc
      Chaintip.check!(:btc, self.bitcoin_core_by_version + self.bitcoin_alternative_implementations)
    when :tbtc
      Chaintip.check!(:tbtc, self.testnet_by_version)
    when :bch
      Chaintip.check!(:bch, self.bch_by_version)
    else
      throw Error, "Unknown coin"
    end
    InvalidBlock.check!(coin)
  end

  def self.getblocktemplate!(coin)
    nodes = Node.where(coin: coin, enabled: true, getblocktemplate: true, unreachable_since: nil)
    throw "Increase RAILS_MAX_THREADS to match #{ nodes.count } #{ coin } nodes." if nodes.count > (ENV["RAILS_MAX_THREADS"] || "5").to_i
    threads = []
    nodes.each do |node|
      threads << Thread.new {
        ActiveRecord::Base.connection_pool.with_connection do
          template = node.rpc_getblocktemplate
          BlockTemplate.create_with(node, template)
        end
      }
    end
    threads.each(&:join)
  end

  # Deleting a node takes very long, causing a timeout when done from the admin panel
  def self.destroy_if_requested(coin)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    Node.where(coin: coin, to_destroy: true).limit(1).each do |node|
      Rails.logger.info "Deleting #{ node.coin.upcase } node #{ node.id }: #{ node.name_with_version }"
      node.destroy
    end
  end

  # Sometimes an empty chaintip is left over
  def self.prune_empty_chaintips!(coin)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    Chaintip.includes(:node).where(coin: coin).where(nodes: { id: nil }).destroy_all
  end

  def self.check_laggards!(options = {})
    if !options[:coins] || options[:coins].empty? || options[:coins].include?("BTC")
      core_nodes = self.bitcoin_core_by_version
      core_nodes.drop(1).each do |node|
        lag  = node.check_if_behind!(core_nodes.first)
        Rails.logger.debug "Check if #{ node.name_with_version } is behind #{ core_nodes.first.name_with_version }... #{ lag.present? }"
      end

      self.bitcoin_alternative_implementations.each do |node|
        next if options[:repeat] && node.client_type.to_sym == :libbitcoin
        lag  = node.check_if_behind!(core_nodes.first)
        Rails.logger.debug "Check if #{ node.name_with_version } is behind #{ core_nodes.first.name_with_version }... #{ lag.present? }"
      end
    end
  end

  # Also marks ancestor blocks valid
  def self.fetch_ancestors!(until_height)
    node = Node.bitcoin_core_by_version.first
    throw "Node in Initial Blockchain Download" if node.ibd
    node.block.find_ancestors!(node, false, true, until_height)
  end

  def self.first_with_txindex(coin, client_type = :core)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    node = Node.where(coin: coin, txindex: true, client_type: client_type, ibd: false, enabled: true, special: false).first or raise NoTxIndexError
  end

  def self.newest(coin, client_type)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    node = Node.where(coin: coin, client_type: client_type, unreachable_since: nil, ibd: false, enabled: true, special: false).order(version: :desc).first or raise NoMatchingNodeError
  end

  def self.first_newer_than(coin, version, client_type)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    node = Node.where("version >= ?", version).where(coin: coin, client_type: client_type, unreachable_since: nil, ibd: false, enabled: true, special: false).first or raise NoMatchingNodeError
  end

  def self.getrawtransaction(tx_id, coin, verbose = false, block_hash = nil)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin)
    first_with_txindex(coin).getrawtransaction(tx_id, verbose, block_hash)
  end

  private

  def self.client_klass
    Rails.env.test? ? BitcoinClientMock : BitcoinClient
  end

  def self.last_updated_cached(coin)
    raise InvalidCoinError unless SUPPORTED_COINS.include?(coin.downcase.to_sym)
    Rails.cache.fetch("Node.last_updated(#{ coin })") { where(coin: coin.downcase.to_sym).order(updated_at: :desc).first }
  end

  def clear_references
    Block.where(coin: self.coin).where("? = ANY(marked_valid_by)", self.id).each do |b|
      b.update marked_valid_by: b.marked_valid_by - [self.id]
    end

    Block.where(coin: self.coin).where("? = ANY(marked_invalid_by)", self.id).each do |b|
      b.update marked_invalid_by: b.marked_invalid_by - [self.id]
    end
  end

  def expire_cache
      Rails.cache.delete("Node.last_updated(#{self.coin.to_s.upcase})")
  end

  def clear_chaintips
    return if self.enabled
    Chaintip.where(node: self).destroy_all
  end

end
