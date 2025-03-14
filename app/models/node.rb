# frozen_string_literal: true

class Node < ApplicationRecord
  include ::TxIdConcern
  include ::BitcoinUtil
  include ::RpcConcern

  class NoMatchingNodeError < StandardError; end

  class NoTxIndexError < StandardError; end

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
  has_many :softforks, dependent: :destroy

  scope :bitcoin_core_by_version, lambda {
                                    where(enabled: true, client_type: :core).where.not(version: nil).order(version: :desc)
                                  }
  scope :bitcoin_core_unknown_version, -> { where(enabled: true, client_type: :core).where(version: nil) }
  scope :bitcoin_alternative_implementations, -> { where(enabled: true).where.not(client_type: :core) }

  # Enum is stored as an integer, so do not remove entries from this list:
  enum client_type: { core: 0, bcoin: 1, knots: 2, btcd: 3, libbitcoin: 4, abc: 5, sv: 6, bu: 7,
                      omni: 8, blockcore: 9 }

  def name_with_version
    BitcoinUtil::Version.name_with_version(name, version, version_extra, client_type.to_sym)
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
      checkpoints
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
    ]
    fields << :id << :rpchost << :mirror_rpchost << :rpcport << :mirror_rpcport << :rpcuser << :rpcpassword << :version_extra << :name << :enabled if options && options[:admin]
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
                  BitcoinClientPython.new(id, name_with_version, client_type.to_sym,
                                          version)
                else
                  client_klass.new(id, name_with_version,
                                   client_type.to_sym, version, rpchost, rpcport, rpcuser, rpcpassword)
                end
    @client
  end

  def mirror_client
    return nil unless mirror_rpchost

    @mirror_client ||= if python
                         BitcoinClientPython.new(id, name_with_version,
                                                 client_type.to_sym, version)
                       else
                         client_klass.new(id, name_with_version,
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
        begin
          info = client.getinfo
        rescue BitcoinUtil::RPC::Error
          update unreachable_since: unreachable_since || DateTime.now
          return
        end
      end
    end

    best_block_hash ||= if blockchaininfo.present?
                          blockchaininfo['bestblockhash']
                        else
                          info.present? ? client.getblockhash(info['blocks']) : nil
                        end

    raise 'Best block hash unexpectedly nil' if best_block_hash.blank?

    if networkinfo.present?
      update(version: BitcoinUtil::Version.parse(networkinfo['version'], client_type.to_sym), peer_count: networkinfo['connections'])
    elsif info.present?
      update(version: BitcoinUtil::Version.parse(info['version'], client_type.to_sym), peer_count: info['connections'])
    end

    if libbitcoin?
      ibd = block_height < 631_885
    elsif blockchaininfo.present?
      block_height = blockchaininfo['blocks']
      ibd = if blockchaininfo.key?('initialblockdownload')
              blockchaininfo['initialblockdownload']
            elsif blockchaininfo.key?('verificationprogress')
              blockchaininfo['verificationprogress'] < 0.9999
            else
              # Don't set too tight because it will silence node behind warnings
              info['blocks'] < Block.maximum(:height) - 1000
            end
    end
    update ibd: ibd, sync_height: ibd ? block_height : nil

    # Get soft fork info using getdeploymentinfo for Bitcoin Core v23.0 and up
    if core? && version.present? && version >= 230_000
      begin
        deploymentinfo = client.getdeploymentinfo
        Softfork.process_deploymentinfo(self, deploymentinfo)
      rescue BitcoinUtil::RPC::Error
        update unreachable_since: unreachable_since || DateTime.now
        return
      end
    # Get soft fork info for older nodes
    elsif blockchaininfo.present?
      Softfork.process(self, blockchaininfo) if core? || knots?
    end

    mempool_bytes = nil
    mempool_count = nil
    mempool_max = nil
    unless libbitcoin?
      begin
        mempool_info = client.getmempoolinfo
        mempool_bytes = mempool_info['bytes']
        mempool_count = mempool_info['size']
        mempool_max = mempool_info['maxmempool']
      rescue BitcoinUtil::RPC::TimeOutError
        # Ignore the occasional timeout
      end

    end

    has_tx_index = nil
    has_coinstatsindex_index = nil
    if core? && version >= 210_000
      index_info = client.getindexinfo
      has_tx_index = index_info.key? 'txindex'
      has_coinstatsindex_index = index_info.key? 'coinstatsindex'
    end

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
      mempool_max: mempool_max,
      txindex: has_tx_index.nil? ? txindex : has_tx_index, # Set by admin before v0.21
      coinstatsindex: has_coinstatsindex_index
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

    return nil if block.work.nil? || node.block.work.nil?

    blocks_behind = nil
    # Use chaintips for Bitcoin Core nodes, and a simpler heuristic for other nodes
    if core?
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
    else
      # Not behind if at the same block
      if block == node.block
        behind = false
      # Compare work:
      elsif block.work < node.block.work
        behind = true
      end

      blocks_behind = node.block.height - block.height
    end

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
    return false if lag_entry && ((Time.zone.now - lag_entry.created_at) < (ENV.fetch('LAG_GRACE_PERIOD') { (1 * 60) }).to_i)

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
    current_alerts = VersionBit.where(deactivate: nil).index_by(&:bit)
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
    Block.where('? = ANY(marked_valid_by)', id).find_each do |b|
      b.update marked_valid_by: b.marked_valid_by - [id]
    end

    Block.where('? = ANY(marked_invalid_by)', id).find_each do |b|
      b.update marked_invalid_by: b.marked_invalid_by - [id]
    end
  end

  def expire_cache
    Rails.cache.delete('Node.last_updated')
  end

  def clear_chaintips
    return if enabled

    Chaintip.where(node: self).destroy_all
  end

  class << self
    def by_version
      where(enabled: true).order(version: :desc)
    end

    def with_mirror
      where(enabled: true, client_type: :core).where.not(mirror_rpchost: nil).order(version: :desc)
    end

    def poll!(options = {})
      bitcoin_core_by_version.each do |node|
        next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago

        Rails.logger.info "Polling node #{node.id} (#{node.name_with_version})..."
        node.poll!
      end

      bitcoin_core_unknown_version.each do |node|
        next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago

        Rails.logger.info "Polling node #{node.id} (unknown verison)..."
        node.poll!
      end

      bitcoin_alternative_implementations.each do |node|
        next if options[:unless_fresh] && node.polled_at.present? && node.polled_at > 5.minutes.ago
        # Skip libbitcoin in repeat poll, due to ZMQ socket errors
        next if options[:repeat] && node.client_type.to_sym == :libbitcoin

        Rails.logger.info "Polling node #{node.id} (#{node.name_with_version})..."
        node.poll!
      end

      check_chaintips!
      StaleCandidate.check!

      check_laggards!(options)

      bitcoin_core_by_version.first.check_versionbits!
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
        Rails.logger.info 'Polling nodes...'
        sleep 5

        poll!(options.merge({ repeat: true }))

        if Rails.env.test?
          break
        else
          sleep 0.5
        end
      end
    end

    def newest_node
      Node.newest(:core)
    end

    # Find pool name for a block. For modern nodes it uses getrawtransaction
    # with a blockhash argument, so a txindex is not required.
    # For older nodes it could process the raw block instead of using getrawtransaction,
    # but that has not been implemented.
    def get_coinbase_for_block!(block, block_info = nil)
      node = nil
      begin
        # getrawtransaction supports blockhash as of version 0.16, perhaps earlier too
        node = Node.first_newer_than(160_000, :core)
      rescue Node::NoMatchingNodeError
        Rails.logger.warn 'Unable to find suitable node in get_coinbase_for_block'
        return nil
      end
      if node.nil?
        Rails.logger.warn 'Unable to find suitable node in get_coinbase_for_block'
        return nil
      end
      begin
        block_info ||= node.getblock(block.block_hash, 1)
      rescue BitcoinUtil::RPC::BlockPrunedError, BitcoinUtil::RPC::BlockNotFoundError
        return nil
      rescue BitcoinUtil::RPC::Error
        logger.error "Unable to fetch block #{block.block_hash} from #{node.name_with_version} while looking for pool name"
        return nil
      end
      return nil if block_info['height'].nil? # Can't fetch the genesis coinbase
      return nil if block_info['tx'].nil? || block_info['tx'].to_a.empty?

      if block_info['tx'].first.instance_of? String
        tx_id = block_info['tx'].first
        begin
          node.getrawtransaction(tx_id, true, block.block_hash)
        rescue BitcoinUtil::RPC::TxNotFoundError
          nil
        end
      else
        block_info['tx'].first
      end
    end

    def set_pool_for_block!(block, block_info = nil)
      coinbase = get_coinbase_for_block!(block, block_info)
      return if coinbase.nil? || coinbase == {}

      block.pool = Block.pool_from_coinbase_tx(coinbase)
      block.total_fee = ((coinbase['vout'].sum do |vout|
                            vout['value']
                          end * 100_000_000.0) - block.max_inflation) / 100_000_000.0
      if block.pool.nil?
        coinbase_message = Block.coinbase_message(coinbase)
        return if coinbase_message.nil?

        block.coinbase_message = coinbase_message.unpack('H*')
      end
      block.save if block.changed?
    end

    def rollback_checks_repeat!
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
        # TODO: find_missing shouldn't need to use a mirror node, but the current
        #       pattern of disconecting is not ideal for the main node.
        Block.find_missing(40_000, 20) # waits 20 seconds for blocks
        InflatedBlock.check_inflation!({ max: 10 })
        Node.where(client_type: :core).where.not(mirror_rpchost: nil).find_each do |node|
          # validate_forks! relies on the mirror node having been polled by check_inflation!
          Chaintip.validate_forks!(node, 50)
        end

        if Rails.env.test?
          break
        else
          sleep 0.5
        end
      end
    end

    def heavy_checks_repeat!
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
        Block.match_missing_pools!(3)
        StaleCandidate.process!
        StaleCandidate.prime_cache
        Softfork.notify!
        Node.destroy_if_requested

        if Rails.env.test?
          break
        else
          sleep 0.5
        end
      end
    end

    def check_chaintips!
      Chaintip.check!(bitcoin_core_by_version + bitcoin_alternative_implementations)
      InvalidBlock.check!
    end

    # Deleting a node takes very long, causing a timeout when done from the admin panel
    def destroy_if_requested
      Node.where(to_destroy: true).limit(1).each do |node|
        Rails.logger.info "Deleting node #{node.id}: #{node.name_with_version}"
        node.destroy
      end
    end

    # Sometimes an empty chaintip is left over
    def prune_empty_chaintips!
      Chaintip.includes(:node).where(nodes: { id: nil }).destroy_all
    end

    def check_laggards!(options = {})
      Lag.where('created_at < ?', 1.day.ago).destroy_all
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

    # Also marks ancestor blocks valid
    def fetch_ancestors!(until_height)
      node = Node.bitcoin_core_by_version.first
      throw 'Node in Initial Blockchain Download' if node.ibd
      node.block.find_ancestors!(node, false, true, until_height)
    end

    def first_with_txindex(client_type = :core)
      Node.find_by(txindex: true, client_type: client_type, ibd: false,
                   enabled: true) or raise BitcoinUtil::RPC::NoTxIndexError
    end

    def newest(client_type)
      Node.where(client_type: client_type, unreachable_since: nil, ibd: false,
                 enabled: true).order(version: :desc).first or raise NoMatchingNodeError
    end

    def first_newer_than(version, client_type)
      Node.where(client_type: client_type, unreachable_since: nil,
                 ibd: false, enabled: true).find_by('version >= ?', version) or raise NoMatchingNodeError
    end

    def last_updated_cached
      Rails.cache.fetch('Node.last_updated') do
        order(updated_at: :desc).first
      end
    end
  end
end
