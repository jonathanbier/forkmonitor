# frozen_string_literal: true

class Node < ApplicationRecord
  include ::TxIdConcern
  include ::BitcoinUtil
  include ::RpcConcern

  class NoMatchingNodeError < StandardError; end

  class NoTxIndexError < StandardError; end

  # BSV support has been removed, but enums are stored as integer in the database.
  enum coin: { btc: 0, bch: 1, bsv: 2, tbtc: 3 }

  nilify_blanks only: [:mirror_rpchost]

  before_save :clear_chaintips, if: :will_save_change_to_enabled?
  before_destroy :clear_references
  after_commit :expire_cache

  belongs_to :block, optional: true
  has_many :chaintips, dependent: :destroy
  has_many :blocks_first_seen, class_name: 'Block', foreign_key: 'first_seen_by_id', dependent: :nullify
  has_many :invalid_blocks, dependent: :restrict_with_exception
  has_many :inflated_blocks, dependent: :restrict_with_exception
  has_many :lag_a, class_name: 'Lag', foreign_key: 'node_a_id', dependent: :destroy
  has_many :lag_b, class_name: 'Lag', foreign_key: 'node_b_id', dependent: :destroy
  has_many :tx_outsets, dependent: :destroy
  belongs_to :mirror_block, optional: true, class_name: 'Block'
  has_one :active_chaintip, -> { where(status: 'active') }, class_name: 'Chaintip'
  has_many :softforks

  scope :bitcoin_core_by_version, lambda {
                                    where(enabled: true, coin: :btc, client_type: :core).where.not(version: nil).order(version: :desc)
                                  }
  scope :bitcoin_core_unknown_version, -> { where(enabled: true, coin: :btc, client_type: :core).where(version: nil) }
  scope :bitcoin_alternative_implementations, -> { where(enabled: true, coin: :btc).where.not(client_type: :core) }

  # Enum is stored as an integer, so do not remove entries from this list:
  enum client_type: { core: 0, bcoin: 1, knots: 2, btcd: 3, libbitcoin: 4, abc: 5, sv: 6, bu: 7,
                      omni: 8, blockcore: 9 }

  scope :testnet_by_version, -> { where(enabled: true, coin: :tbtc).order(version: :desc) }
  scope :bch_by_version, -> { where(enabled: true, coin: :bch).order(version: :desc) }

  def name_with_version
    BitcoinUtil::Version.name_with_version(name, version, version_extra, bu?)
  end

  def as_json(options = nil)
    fields = %i[
      id
      unreachable_since
      mirror_unreachable_since
      ibd
      client_type
      pruned
      txindex
      os
      cpu
      ram
      storage
      cve_2018_17144
      released
      sync_height
      link
      link_text
      mempool_count
      mempool_bytes
      mempool_max
      mirror_ibd
      to_destroy
      getblocktemplate
    ]
    if options && options[:admin]
      fields << :id << :coin << :rpchost << :mirror_rpchost << :rpcport << :mirror_rpcport << :rpcuser << :rpcpassword << :version_extra << :name << :enabled
    end
    super({ only: fields }.merge(options || {})).merge({
                                                         height: active_chaintip&.block&.height,
                                                         name_with_version: name_with_version,
                                                         tx_outset: tx_outset,
                                                         last_tx_outset: tx_outsets.last,
                                                         has_mirror_node: mirror_rpchost.present?,
                                                         bip9_softforks: softforks.where(fork_type: :bip9), # rubocop:disable Naming/VariableNumber
                                                         bip8_softforks: softforks.where(fork_type: :bip8) # rubocop:disable Naming/VariableNumber
                                                       })
  end

  def client
    @client ||= if python
                  BitcoinClientPython.new(id, name_with_version, coin.to_sym, client_type.to_sym,
                                          version)
                else
                  client_klass.new(id, name_with_version, coin.to_sym,
                                   client_type.to_sym, version, rpchost, rpcport, rpcuser, rpcpassword)
                end
    @client
  end

  def mirror_client
    return nil unless mirror_rpchost

    @mirror_client ||= if python
                         BitcoinClientPython.new(id, name_with_version, coin.to_sym,
                                                 client_type.to_sym, version)
                       else
                         client_klass.new(id, name_with_version, coin.to_sym,
                                          client_type.to_sym, version, mirror_rpchost, mirror_rpcport, rpcuser, rpcpassword)
                       end
    @mirror_client
  end

  def tx_outset
    tx_outsets.find_by(block: block)
  end

  # Update database with latest info from this node
  def poll!
    if libbitcoin?
      block_height = client.getblockheight
      if block_height.nil?
        update unreachable_since: unreachable_since || DateTime.now
        return
      end
      header = client.getblockheader(block_height)
      best_block_hash = header['hash']
    elsif btcd?
      begin
        blockchaininfo = client.getblockchaininfo
        info = client.getinfo
      rescue BitcoinUtil::RPC::Error
        update unreachable_since: unreachable_since || DateTime.now
        return
      end
    elsif core? && version.present? && version < 100_000
      begin
        info = client.getinfo
      rescue BitcoinUtil::RPC::Error
        update unreachable_since: unreachable_since || DateTime.now
        return
      end
    elsif core? && version.present?
      begin
        blockchaininfo = client.getblockchaininfo
        networkinfo = client.getnetworkinfo
      rescue BitcoinUtil::RPC::Error
        update unreachable_since: unreachable_since || DateTime.now
        return
      end
    else # Version is not known the first time
      begin
        blockchaininfo = client.getblockchaininfo
        networkinfo = client.getnetworkinfo
      rescue BitcoinUtil::RPC::Error
        # Try getinfo for ancient nodes:
        begin
          info = client.getinfo
        rescue BitcoinUtil::RPC::Error
          update unreachable_since: unreachable_since || DateTime.now
          return
        end
      end
    end

    if networkinfo.present?
      update(version: BitcoinUtil::Version.parse(networkinfo['version']), peer_count: networkinfo['connections'])
    elsif info.present?
      update(version: BitcoinUtil::Version.parse(info['version']), peer_count: info['connections'])
    end

    if libbitcoin?
      ibd = block_height < 631_885
    elsif blockchaininfo.present?
      block_height = blockchaininfo['blocks']
      if blockchaininfo.key?('initialblockdownload')
        ibd = blockchaininfo['initialblockdownload']
      elsif blockchaininfo.key?('verificationprogress')
        ibd = blockchaininfo['verificationprogress'] < 0.9999
      elsif btc?
        ibd = info['blocks'] < Block.where(coin: :btc).maximum(:height) - 10
      end
    end
    update ibd: ibd, sync_height: ibd ? block_height : nil

    if blockchaininfo.present?
      best_block_hash = blockchaininfo['bestblockhash']
      Softfork.process(self, blockchaininfo) if btc? && (core? || knots?)
    elsif info.present?
      best_block_hash = client.getblockhash(info['blocks'])
    end

    mempool_bytes = nil
    mempool_count = nil
    mempool_max = nil
    unless libbitcoin?
      mempool_info = client.getmempoolinfo
      mempool_bytes = mempool_info['bytes']
      mempool_count = mempool_info['size']
      mempool_max = mempool_info['maxmempool']
    end

    raise 'Best block hash unexpectedly nil' if best_block_hash.blank?

    # Mark node as reachable (if needed) before trying to fetch additional info
    # such as the coinbase message.
    update polled_at: Time.zone.now, unreachable_since: nil if unreachable_since

    block = self.ibd ? nil : Block.find_or_create_block_and_ancestors!(best_block_hash, self, false, true)

    update(
      polled_at: Time.zone.now,
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
    return unless core?

    Rails.logger.info 'Polling mirror node...'
    begin
      blockchaininfo = mirror_client.getblockchaininfo
    rescue BitcoinUtil::RPC::Error
      Rails.logger.info 'Failed to poll mirror node...'
      # Ignore failure
      return
    end
    best_block_hash = blockchaininfo['bestblockhash']
    ibd = blockchaininfo['initialblockdownload']
    block = ibd ? nil : Block.find_or_create_block_and_ancestors!(best_block_hash, self, true, nil)
    update mirror_block: block, last_polled_mirror_at: Time.zone.now, mirror_ibd: ibd
  end

  # Should be run after polling all nodes, otherwise it may find false positives
  def check_if_behind!(node)
    # Return nil if other node is in IBD:
    return nil if node.ibd

    # Return nil if this node is in IBD:
    return nil if ibd

    # Return nil if this node has no peers:
    return nil if peer_count.nil? || peer_count.zero?

    # Return nil if either node is unreachble:
    return nil if unreachable_since || node.unreachable_since

    behind = nil
    lag_entry = Lag.find_by(node_a: self, node_b: node)

    return nil if block.nil? || node.block.nil?

    return nil if active_chaintip.nil? || node.active_chaintip.nil?

    # Sometimes the work field is missing:
    return nil if active_chaintip.block.work.nil? || node.active_chaintip.block.work.nil?

    # Not behind if at the same block
    if active_chaintip.block == node.active_chaintip.block
      behind = false
    # Compare work:
    elsif active_chaintip.block.work < node.active_chaintip.block.work
      behind = true
    end

    blocks_behind = node.active_chaintip.block.height - active_chaintip.block.height

    # Allow 1 block extra for 0.16 nodes and older:
    return nil if core? && version < 169_999 && blocks_behind < 2

    # Allow 1 block extra for btcd and Knots nodes:
    return nil if (btcd? || knots?) && blocks_behind < 2

    # Allow 10 blocks extra for libbitcion nodes:
    return nil if libbitcoin? && blocks_behind < 10

    # Remove entry if no longer behind
    if lag_entry && !behind
      lag_entry.destroy
      return nil
    end

    if behind
      if !lag_entry
        # Store when we first discover the lag
        lag_entry = Lag.create(node_a: self, node_b: node, blocks: blocks_behind)
      elsif lag_entry.blocks < blocks_behind
        # Update block count, but only if it increased:
        lag_entry.update blocks: blocks_behind
      end
    end

    # Return false if behind but still in grace period:
    return false if lag_entry && ((Time.zone.now - lag_entry.created_at) < (ENV['LAG_GRACE_PERIOD'] || 1 * 60).to_i)

    if lag_entry
      # Mark as ready to publish on RSS
      lag_entry.update publish: true

      # Send email after grace period
      unless lag_entry.notified_at
        lag_entry.update notified_at: Time.zone.now
        User.all.find_each do |user|
          UserMailer.with(user: user, lag: lag_entry).lag_email.deliver
        end
      end
    end

    lag_entry
  end

  def check_versionbits!
    return nil if ibd

    reload # Block parent links may be stale otherwise

    threshold = Rails.env.test? ? 2 : ENV['VERSION_BITS_THRESHOLD'].to_i || 50

    block = self.block
    return nil if block.nil?

    until_height = block.height - (VersionBit::WINDOW - 1)

    versions_window = []

    while block.present? && block.height >= until_height
      if block.version.blank?
        Rails.logger.error "Missing version for block #{block.height}"
        return nil
      end

      versions_window.push(block.version_bits)
      block = block.parent
    end

    return nil if versions_window.length != VersionBit::WINDOW # Less than 100 blocks or missing parent info

    versions_tally = versions_window.transpose.map(&:sum)
    throw "Unexpected versions_tally = #{versions_tally.length} != 29" if versions_tally.length != 29
    current_alerts = VersionBit.where(deactivate: nil).index_by { |vb| vb.bit }
    known_softforks = Softfork.all.collect(&:bit).uniq
    versions_tally.each_with_index do |tally, bit|
      next if known_softforks.include?(bit)

      if tally >= threshold
        if current_alerts[bit].nil?
          Rails.logger.info "Bit #{bit} exceeds threshold"
          current_alerts[bit] = VersionBit.create(bit: bit, activate: self.block)
        end
      elsif tally.zero?
        current_alert = current_alerts[bit]
        if current_alert.present?
          Rails.logger.info "Turn off alert for bit #{bit}"
          current_alert.update deactivate: self.block
        end
      end

      # Send email
      current_alert = current_alerts[bit]
      next unless current_alert && !current_alert.deactivate && !current_alert.notified_at

      User.all.find_each do |user|
        UserMailer.with(user: user, bit: bit, tally: tally, window: VersionBit::WINDOW,
                        block: self.block).version_bits_email.deliver
      end
      current_alert.update notified_at: Time.zone.now
    end
  end

  private

  def client_klass
    Rails.env.test? ? BitcoinClientMock : BitcoinClient
  end

  def clear_references
    Block.where(coin: coin).where('? = ANY(marked_valid_by)', id).find_each do |b|
      b.update marked_valid_by: b.marked_valid_by - [id]
    end

    Block.where(coin: coin).where('? = ANY(marked_invalid_by)', id).find_each do |b|
      b.update marked_invalid_by: b.marked_invalid_by - [id]
    end
  end

  def expire_cache
    Rails.cache.delete("Node.last_updated(#{coin.to_s.upcase})")
  end

  def clear_chaintips
    return if enabled

    Chaintip.where(node: self).destroy_all
  end

  class << self
    def coin_by_version(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      where(enabled: true, coin: coin).order(version: :desc)
    end

    def with_mirror(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      where(enabled: true, coin: coin, client_type: :core).where.not(mirror_rpchost: nil).order(version: :desc)
    end

    def poll!(options = {})
      if options[:coins].blank? || options[:coins].include?('BTC')
        bitcoin_core_by_version.each do |node|
          next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago

          Rails.logger.info "Polling #{node.coin} node #{node.id} (#{node.name_with_version})..."
          node.poll!
        end

        bitcoin_core_unknown_version.each do |node|
          next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago

          Rails.logger.info "Polling #{node.coin} node #{node.id} (unknown verison)..."
          node.poll!
        end

        bitcoin_alternative_implementations.each do |node|
          next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago
          # Skip libbitcoin in repeat poll, due to ZMQ socket errors
          next if options[:repeat] && node.client_type.to_sym == :libbitcoin

          Rails.logger.info "Polling #{node.coin} node #{node.id} (#{node.name_with_version})..."
          node.poll!
        end

        check_chaintips!(:btc)
        StaleCandidate.check!(:btc)
      end

      if options[:coins].blank? || options[:coins].include?('TBTC')
        testnet_by_version.each do |node|
          next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago

          Rails.logger.info "Polling #{node.coin} node #{node.id} (#{node.name_with_version})..."
          node.poll!
        end

        check_chaintips!(:tbtc)
        StaleCandidate.check!(:tbtc)
      end

      if options[:coins].blank? || options[:coins].include?('BCH')
        bch_by_version.each do |node|
          next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago

          Rails.logger.info "Polling #{node.coin} node #{node.id} (#{node.name_with_version})..."
          node.poll!
        end

        check_chaintips!(:bch)
        StaleCandidate.check!(:bch)
      end

      check_laggards!(options)

      if options[:coins].blank? || options[:coins].include?('BTC')
        bitcoin_core_by_version.first.check_versionbits!
      end
    end

    def poll_repeat!(options = {})
      # Trap ^C
      Signal.trap('INT') do
        Rails.logger.info "\nShutting down gracefully..."
        exit # rubocop:disable Rails/Exit
      end

      # Trap `Kill `
      Signal.trap('TERM') do
        Rails.logger.info "\nShutting down gracefully..."
        exit # rubocop:disable Rails/Exit
      end

      loop do
        Rails.logger.info "Polling #{options[:coins].join(', ')} nodes..."
        sleep 5

        poll!(options.merge({ repeat: true }))

        if Rails.env.test?
          break
        else
          sleep 0.5
        end
      end
    end

    def newest_node(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      case coin
      when :btc, :tbtc
        return Node.newest(coin, :core)
      when :bch
        return Node.newest(coin, :abc)
      end
      throw "Unable to find suitable #{coin} node in newest_node"
    end

    # Find pool name for a block. For modern nodes it uses getrawtransaction
    # with a blockhash argument, so a txindex is not required.
    # For older nodes it could process the raw block instead of using getrawtransaction,
    # but that has not been implemented.
    # Also returns array with tx ids
    def get_coinbase_and_tx_ids_for_block!(coin, block_hash, block_info = nil)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      node = nil
      begin
        case coin
        when :btc, :tbtc
          # getrawtransaction supports blockhash as of version 0.16, perhaps earlier too
          node = Node.first_newer_than(coin, 160_000, :core)
        when :bch
          # getrawtransaction supports blockhash as of version 0.21, perhaps earlier too
          node = Node.first_newer_than(coin, 210_000, :abc)
        end
      rescue Node::NoMatchingNodeError
        Rails.logger.warn "Unable to find suitable #{coin} node in get_coinbase_and_tx_ids_for_block"
        return nil
      end
      begin
        block_info ||= node.getblock(block_hash, 1)
      rescue BitcoinUtil::RPC::BlockPrunedError, BitcoinUtil::RPC::BlockNotFoundError
        return nil
      rescue BitcoinUtil::RPC::Error
        logger.error "Unable to fetch block #{block_hash} from #{node.name_with_version} while looking for pool name"
        return nil
      end
      return nil if block_info['height'].nil? # Can't fetch the genesis coinbase
      return nil if block_info['tx'].nil?

      tx_id = block_info['tx'].first
      begin
        [node.getrawtransaction(tx_id, true, block_hash), block_info['tx']]
      rescue BitcoinUtil::RPC::TxNotFoundError
        nil
      end
    end

    def set_pool_tx_ids_fee_total_for_block!(coin, block, block_info = nil)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      coinbase, tx_ids = get_coinbase_and_tx_ids_for_block!(coin, block.block_hash, block_info)
      return if coinbase.nil? || coinbase == {}

      tx_ids.shift # skip coinbase
      block.tx_ids = hashes_to_binary(tx_ids)
      block.pool = Block.pool_from_coinbase_tx(coinbase)
      block.total_fee = (coinbase['vout'].sum do |vout|
                           vout['value']
                         end * 100_000_000.0 - block.max_inflation) / 100_000_000.0
      if block.pool.nil?
        coinbase_message = Block.coinbase_message(coinbase)
        return if coinbase_message.nil?

        block.coinbase_message = coinbase_message.unpack('H*')
      end
      block.save if block.changed?
    end

    def rollback_checks_repeat!(options)
      # Trap ^C
      Signal.trap('INT') do
        Rails.logger.info "\nShutting down gracefully..."
        exit # rubocop:disable Rails/Exit
      end

      # Trap `Kill `
      Signal.trap('TERM') do
        Rails.logger.info "\nShutting down gracefully..."
        exit # rubocop:disable Rails/Exit
      end

      loop do
        options[:coins].each do |coin|
          # TODO: find_missing shouldn't need to use a mirror node, but the current
          #       pattern of disconecting is not ideal for the main node.
          Block.find_missing(coin.downcase.to_sym, 40_000, 20) # waits 20 seconds for blocks
          InflatedBlock.check_inflation!({ coin: coin.downcase.to_sym, max: 10 })
          Node.where(coin: coin.downcase.to_sym, client_type: :core).where.not(mirror_rpchost: nil).find_each do |node|
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

    def heavy_checks_repeat!(options)
      # Trap ^C
      Signal.trap('INT') do
        Rails.logger.info "\nShutting down gracefully..."
        exit # rubocop:disable Rails/Exit
      end

      # Trap `Kill `
      Signal.trap('TERM') do
        Rails.logger.info "\nShutting down gracefully..."
        exit # rubocop:disable Rails/Exit
      end

      loop do
        options[:coins].each do |coin|
          LightningTransaction.check!({ coin: coin.downcase.to_sym, max: 1000 }) if coin == 'BTC'
          LightningTransaction.check_public_channels! if coin == 'BTC'
          Block.match_missing_pools!(coin.downcase.to_sym, 3)
          Block.process_templates!(coin.downcase.to_sym)
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

    def getblocktemplate_repeat!(options)
      # Trap ^C
      Signal.trap('INT') do
        Rails.logger.info "\nShutting down gracefully..."
        exit # rubocop:disable Rails/Exit
      end

      # Trap `Kill `
      Signal.trap('TERM') do
        Rails.logger.info "\nShutting down gracefully..."
        exit # rubocop:disable Rails/Exit
      end

      @last_checked = nil

      loop do
        if @last_checked.nil? || @last_checked < 20.seconds.ago
          @last_checked = Time.zone.now
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

    def check_chaintips!(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      case coin
      when :btc
        Chaintip.check!(:btc, bitcoin_core_by_version + bitcoin_alternative_implementations)
      when :tbtc
        Chaintip.check!(:tbtc, testnet_by_version)
      when :bch
        Chaintip.check!(:bch, bch_by_version)
      else
        throw Error, 'Unknown coin'
      end
      InvalidBlock.check!(coin)
    end

    def getblocktemplate!(coin)
      nodes = Node.where(coin: coin, enabled: true, getblocktemplate: true, unreachable_since: nil)
      if nodes.count > (ENV['RAILS_MAX_THREADS'] || '5').to_i
        throw "Increase RAILS_MAX_THREADS to match #{nodes.count} #{coin} nodes."
      end
      threads = []
      nodes.each do |node|
        threads << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            template = node.rpc_getblocktemplate
            BlockTemplate.create_with(node, template)
          end
        end
      end
      threads.each(&:join)
    end

    # Deleting a node takes very long, causing a timeout when done from the admin panel
    def destroy_if_requested(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      Node.where(coin: coin, to_destroy: true).limit(1).each do |node|
        Rails.logger.info "Deleting #{node.coin.upcase} node #{node.id}: #{node.name_with_version}"
        node.destroy
      end
    end

    # Sometimes an empty chaintip is left over
    def prune_empty_chaintips!(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      Chaintip.includes(:node).where(coin: coin).where(nodes: { id: nil }).destroy_all
    end

    def check_laggards!(options = {})
      if options[:coins].blank? || options[:coins].include?('BTC')
        core_nodes = bitcoin_core_by_version
        core_nodes.drop(1).each do |node|
          lag = node.check_if_behind!(core_nodes.first)
          Rails.logger.info "Check if #{node.name_with_version} is behind #{core_nodes.first.name_with_version}... #{lag.present?}"
        end

        bitcoin_alternative_implementations.each do |node|
          next if options[:repeat] && node.client_type.to_sym == :libbitcoin

          lag  = node.check_if_behind!(core_nodes.first)
          Rails.logger.info "Check if #{node.name_with_version} is behind #{core_nodes.first.name_with_version}... #{lag.present?}"
        end
      end
    end

    # Also marks ancestor blocks valid
    def fetch_ancestors!(until_height)
      node = Node.bitcoin_core_by_version.first
      throw 'Node in Initial Blockchain Download' if node.ibd
      node.block.find_ancestors!(node, false, true, until_height)
    end

    def first_with_txindex(coin, client_type = :core)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      Node.find_by(coin: coin, txindex: true, client_type: client_type, ibd: false,
                   enabled: true) or raise BitcoinUtil::RPC::NoTxIndexError
    end

    def newest(coin, client_type)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      Node.where(coin: coin, client_type: client_type, unreachable_since: nil, ibd: false,
                 enabled: true).order(version: :desc).first or raise NoMatchingNodeError
    end

    def first_newer_than(coin, version, client_type)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      Node.where(coin: coin, client_type: client_type, unreachable_since: nil,
                 ibd: false, enabled: true).find_by('version >= ?', version) or raise NoMatchingNodeError
    end

    def last_updated_cached(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin.downcase.to_sym)

      Rails.cache.fetch("Node.last_updated(#{coin})") do
        where(coin: coin.downcase.to_sym).order(updated_at: :desc).first
      end
    end
  end
end
