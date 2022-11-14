# frozen_string_literal: true

require 'csv'

class Block < ApplicationRecord
  include ::TxIdConcern
  include ::BitcoinUtil

  MINIMUM_BLOCK_HEIGHTS = {
    btc: if Rails.env.test?
           0
         else
           # For production, mid December 2017, around Lightning network launch
           # For development: something recent
           (Rails.env.development? ? 763_000 : 500_000)
         end,
    tbtc: 1_600_000,
    bsv: 710_000
  }.freeze

  COIN = 100_000_000

  class RollbackError < StandardError; end

  has_many :children, class_name: 'Block', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Block', optional: true
  has_many :invalid_blocks, dependent: :destroy
  belongs_to :first_seen_by, class_name: 'Node', optional: true
  has_many :tx_outsets, dependent: :destroy
  has_one :inflated_block
  has_many :maybe_uncoop_transactions, dependent: :destroy
  has_many :penalty_transactions, dependent: :destroy
  has_many :sweep_transactions, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :chaintips, dependent: :destroy
  enum coin: { btc: 0, bch: 1, bsv: 2, tbtc: 3 }

  # Used to trigger and restore reorgs on the mirror node
  attr_accessor :invalidated_block_hashes

  after_initialize :set_invalidated_block_hashes

  def as_json(options = nil)
    super({ only: %i[id coin height timestamp created_at pool tx_count size total_fee
                     template_txs_fee_diff] }.merge(options || {})).merge({
                                                                            hash: block_hash,
                                                                            work: log2_pow,
                                                                            first_seen_by: if first_seen_by
                                                                                             {
                                                                                               id: first_seen_by.id,
                                                                                               name_with_version: first_seen_by.name_with_version
                                                                                             }
                                                                                           end
                                                                          })
  end

  def log2_pow
    return nil if work.nil?

    Math.log2(work.to_i(16))
  end

  def version_bits
    # First three bits of field have no meaning in BIP9. nVersion is a little-endian
    # signed integer that must be greater than 2, which is 0x0010 in binary and 0x02 in hex.
    # By setting the least significant byte to >= 0x02 this requirement is met
    # regardless of the next 3 bytes.
    # This is why nVersion changed from 4 (0x00000004) to 536870912 (0x20000000) for most blocks.
    # In fact, nVersion 4 (0x00000004) would now indicate signalling for a soft fork on bit 26.
    #        mask: 0xe0000000 (bit 0-28)
    # BIP320 mask: 0xe0001fff (loses bit 13-28)
    format('%.32b', (version & ~0xe0000000)).chars.drop(3).reverse.collect(&:to_i)
  end

  # https://bitcoin.stackexchange.com/a/9962
  def max_inflation
    interval = height / 210_000
    reward = 50 * 100_000_000
    reward >> interval # as opposed to (reward / 2**interval)
  end

  def descendants(depth_limit = nil)
    block_hash = self.block_hash
    height = self.height
    coin = self.coin
    max_height = depth_limit.nil? ? 10_000_000 : height + depth_limit
    # Constrain query by coin and minimum height to reduce memory usage
    Block.where(coin: coin).where('height > ? AND height <= ?', height, max_height).join_recursive do
      start_with(block_hash: block_hash)
        .connect_by(id: :parent_id)
        .order_siblings(:work)
    end
  end

  # Find branch point with common ancestor, and return the start of the branch,
  # i.e. the block after the common ancenstor
  def branch_start(other_block)
    raise 'same block' if self == other_block

    candidate_branch_start = self
    until candidate_branch_start.nil?
      raise "parent of #{coin.upcase} block #{candidate_branch_start.block_hash} (#{candidate_branch_start.height}) missing" if candidate_branch_start.parent.nil?

      if candidate_branch_start.parent.descendants.include? other_block
        raise 'same branch' if self == candidate_branch_start

        return candidate_branch_start
      end
      candidate_branch_start = candidate_branch_start.parent
    end
    raise 'dead end'
  end

  def fetch_transactions!
    if transactions.count.zero? && !headers_only
      Rails.logger.info "Fetch transactions at height #{height} (#{block_hash})..."
      # TODO: if node doesn't have getblock equivalent (e.g. libbitcoin), try other nodes
      # Workaround for test framework, needed in order to mock first_seen_by
      this_block = Rails.env.test? ? Block.find_by(block_hash: block_hash) : self
      begin
        node = this_block.first_seen_by
        # getblock argument verbosity 2 was added in v0.16.0
        # Knots doesn't return the transaction hash
        node = Node.newest_node(this_block.coin.to_sym) if pruned? || node.nil? || (node.core? && node.version < 160_000) || node.libbitcoin? || node.knots? || node.btcd? || node.bcoin?
        block_info = node.getblock(block_hash, 2, false, nil)
      rescue BitcoinUtil::RPC::BlockPrunedError
        update pruned: true
        return
      rescue BitcoinUtil::RPC::BlockNotFoundError
        # Perhaps the newest node hasn't seen this block yet, just try again later
        return
      end
      throw "Missing transaction data for #{coin.upcase} block #{height} (#{block_hash}) on #{node.name_with_version}" if block_info['tx'].nil?
      block_info['tx'].each_with_index do |tx, i|
        transactions.create(
          is_coinbase: i.zero?,
          tx_id: tx['txid'],
          raw: tx['hex'],
          amount: tx['vout'].sum { |vout| vout['value'] }
        )
      end
    end
  end

  def find_ancestors!(node, use_mirror, mark_valid, until_height = nil)
    block_id = id
    block_ids = []
    client = use_mirror ? node.mirror_client : node.client
    loop do
      block_ids.append(block_id)
      block = Block.find(block_id)
      # Prevent new instances from going too far back:
      minimum_height = node.client.instance_of?(BitcoinClientMock) ? 560_176 : Block::MINIMUM_BLOCK_HEIGHTS[block.coin.to_sym]
      break if block.height.zero? || block.height <= minimum_height
      break if until_height && block.height == until_height

      parent = block.parent
      if parent.nil?
        if node.client_type.to_sym == :libbitcoin
          block_info = client.getblockheader(block.block_hash)
        else
          begin
            block_info = node.getblock(block.block_hash, 1, use_mirror)
          rescue BitcoinUtil::RPC::BlockPrunedError
            block_info = client.getblockheader(block.block_hash)
          end
        end
        throw 'block_info unexpectedly empty' if block_info.blank?
        parent = Block.find_by(block_hash: block_info['previousblockhash'])
        block.update parent: parent
      end
      if parent.present?
        break if until_height.nil? && parent.connected
      else
        # Fetch parent block:
        break unless id

        Rails.logger.info "Fetch intermediate block at height #{block.height - 1}" unless Rails.env.test?
        if node.client_type.to_sym == :libbitcoin
          block_info = client.getblockheader(block_info['previousblockhash'])
        else
          begin
            block_info = node.getblock(block_info['previousblockhash'], 1, use_mirror)
          rescue BitcoinUtil::RPC::BlockPrunedError
            block_info = client.getblockheader(block_info['previousblockhash'])
          end
        end

        parent = Block.create_or_update_with(block_info, use_mirror, node, mark_valid)
        block.update parent: parent
      end
      block_id = parent.id
    end
    # Go back up to the tip to mark blocks as connected
    return if until_height && !Block.find(block_id).connected

    Block.where('id in (?)', block_ids).update connected: true
  end

  def summary(time: false, first_seen_by: false)
    result = "#{block_hash} ("
    result += "#{(size / 1000.0 / 1000.0).round(2)} MB, " if size.present?
    result += "#{Time.at(timestamp).utc.strftime('%H:%M:%S')} by " if time && timestamp.present?
    result += (pool.presence || 'unknown pool').to_s
    result += ", first seen by #{self.first_seen_by.name_with_version}" if first_seen_by && self.first_seen_by.present?
    "#{result})"
  end

  def block_and_descendant_transaction_ids(depth_limit)
    ([self] + descendants(depth_limit)).collect do |b|
      b.transactions.where(is_coinbase: false).select(:tx_id)
    end.flatten.collect(&:tx_id).uniq
  end

  # Preloads tx_id, raw and amount
  def block_and_descendant_transactions(depth_limit)
    ([self] + descendants(depth_limit)).collect do |b|
      b.transactions.where(is_coinbase: false).select(:tx_id, :raw, :amount)
    end.flatten
  end

  def update_fields(block_info)
    self.work = block_info['chainwork']
    self.mediantime = block_info['mediantime']
    self.timestamp = block_info['time']
    self.work = block_info['chainwork']
    self.version = block_info['version']
    self.tx_count = Block.extract_tx_count(block_info)
    self.size = block_info['size']
    # Connect to parent if available:
    if parent.nil?
      self.parent = Block.find_by(block_hash: block_info['previousblockhash'])
      self.connected = parent.nil? ? false : parent.connected
    end
    save if changed?
  end

  def fetch_header!(node)
    begin
      block_info = node.getblockheader(block_hash)
      update_fields(block_info)
    rescue BitcoinUtil::RPC::MethodNotFoundError, BitcoinUtil::RPC::BlockNotFoundError, BitcoinUtil::RPC::TimeOutError
      # Ignore old clients that don't support getblockheader, and try again
      # later if block is not found or there's a timeout.
      return false
    end
    true
  end

  def set_template_diff!
    # Transactions and total fee may be missing e.g. if this is a headers only block:
    return if total_fee.nil?

    last_template = BlockTemplate.where(height: height).last
    return if last_template.nil?

    update template_txs_fee_diff: total_fee - last_template.fee_total
  end

  def expire_stale_candidate_cache
    StaleCandidate.where(coin: coin).find_each do |c|
      c.expire_cache if height - c.height <= StaleCandidate::STALE_BLOCK_WINDOW
    end
  end

  def set_invalidated_block_hashes
    @invalidated_block_hashes = []
  end

  def make_active_on_mirror!(node)
    # Invalidate new blocks, including any forks we don't know of yet
    Rails.logger.info "Roll back the chain to #{block_hash} (#{height}) on #{node.name_with_version}..."
    tally = 0
    while true
      active_tip = node.get_mirror_active_tip
      break if active_tip.blank?
      break if block_hash == active_tip['hash']

      if tally > (Rails.env.test? ? 2 : 100)
        throw_unable_to_roll_back!(node)
      elsif tally.positive?
        Rails.logger.info "Fetch blocks for any newly activated chaintips on #{node.name_with_version}..."
        node.poll_mirror!
        reload
      end
      Rails.logger.info "Current tip #{active_tip['hash']} (#{active_tip['height']}) on #{node.name_with_version}"
      blocks_to_invalidate = []
      active_tip_block = Block.find_by!(block_hash: active_tip['hash'])
      if height == active_tip['height']
        Rails.logger.info 'Invalidate tip to jump to another fork'
        blocks_to_invalidate.append(active_tip_block)
      else
        Rails.logger.info "Check if active chaintip (#{active_tip['height']}) descends from target block (#{height}), otherwise invalidate the active chain..."
        blocks_to_invalidate.append(active_tip_block.branch_start(self)) unless active_tip_block.height <= height || descendants.include?(active_tip_block)
        # Invalidate all child blocks we know of, if the node knows them
        children.each do |child_block|
          begin
            node.mirror_client.getblockheader(child_block.block_hash)
          rescue BitcoinUtil::RPC::Error
            Rails.logger.error "Skip invalidation of #{child_block.block_hash} (#{child_block.height}) on #{node.name_with_version} because mirror node doesn't have it"
            next
          end
          blocks_to_invalidate.append(child_block) unless @invalidated_block_hashes.include?(child_block.block_hash)
        end
      end
      # Stop if there are no new blocks to invalidate
      if (blocks_to_invalidate.collect(&:block_hash) - @invalidated_block_hashes).empty?
        Rails.logger.error "Nothing to invalidate on #{node.name_with_version}"
        throw_unable_to_roll_back!(node, blocks_to_invalidate, @invalidated_block_hashes)
      end
      blocks_to_invalidate.each do |block|
        @invalidated_block_hashes.append(block.block_hash)
        Rails.logger.info "Invalidate block #{block.block_hash} (#{block.height}) on #{node.name_with_version}"
        node.mirror_client.invalidateblock(block.block_hash) # This is a blocking call
      end
      tally += 1
      # Give node some time to update its internals. There were occasional
      # failures where the gettxoutsetinfo below would be applied to the
      # child block, despite checks against that.
      sleep 3
    end

    throw "No active tip left after rollback on #{node.name_with_version}. Was expecting #{block_hash} (#{height})" if active_tip.blank?
    throw "Unexpected active tip hash #{active_tip['hash']} (#{active_tip['height']}) instead of #{block_hash} (#{height}) on #{node.name_with_version}" unless active_tip['hash'] == block_hash
  end

  def throw_unable_to_roll_back!(node, blocks_to_invalidate = nil, invalidated_block_hashes = nil)
    error = "Unable to roll active #{coin.upcase} chaintip to #{block_hash} (#{height}) on node #{node.id} #{node.name_with_version}"
    error += "\nChaintips: #{node.mirror_client.getchaintips.filter do |t|
                               t['height'] > height - 100
                             end.collect { |t| "#{t['hash']} (#{t['height']})=#{t['status']}" }.join(', ')}"
    unless invalidated_block_hashes.nil?
      error += "\nInvalidated blocks: #{invalidated_block_hashes.collect do |b|
                                          "#{b.block_hash} (#{b.height})"
                                        end.join(', ')}"
    end
    unless blocks_to_invalidate.nil?
      error += "\nBlocks to invalidate: #{blocks_to_invalidate.collect do |b|
                                            "#{b.block_hash} (#{b.height})"
                                          end.join(', ')}"
    end
    raise RollbackError, error
  end

  def undo_rollback!(node)
    unless invalidated_block_hashes.empty?
      Rails.logger.info "Restore chain to tip on #{node.name_with_version}..."
      invalidated_block_hashes.each do |block_hash|
        Rails.logger.info "Reconsider block #{block_hash} (#{height}) on #{node.name_with_version}"
        node.mirror_client.reconsiderblock(block_hash) # This is a blocking call
        sleep 1 # But wait anyway
      end
      self.invalidated_block_hashes = []
    end
  end

  def validate_fork!(node)
    return nil if node.mirror_rpchost.blank?
    return nil if marked_valid_by.include?(node.id) || marked_invalid_by.include?(node.id)

    # Feed header and block to mirror node if needed:
    begin
      node.mirror_client.getblock(block_hash, 1)
    rescue BitcoinUtil::RPC::BlockNotFoundError
      return nil if first_seen_by.libbitcoin?

      Rails.logger.info "Feed block #{block_hash} (#{height}) from #{first_seen_by.name_with_version} to mirror of #{node.name_with_version}"
      raw_block_header = first_seen_by.getblockheader(block_hash, false)
      raw_block = first_seen_by.client.getblock(block_hash, 0)
      begin
        node.mirror_client.submitheader(raw_block_header)
      rescue BitcoinUtil::RPC::PreviousHeaderMissing
        # This can happen if the mirror node is too far behind or if the stale fork is longer than 1
        Rails.logger.error 'Failed to provide mirror node with block header'
        # TODO: call submitheader multiple times if needed
        return nil
      end
      node.mirror_client.submitblock(raw_block, block_hash)
      sleep 3
      # Check if this succeeded
      begin
        node.mirror_client.getblock(block_hash, 1)
      rescue BitcoinUtil::RPC::BlockNotFoundError
        Rails.logger.error 'Failed to provide mirror node with block'
        return nil
      end
    end

    Rails.logger.info 'Stop p2p networking to prevent the chain from updating underneath us'
    node.mirror_client.setnetworkactive(false)

    begin
      make_active_on_mirror!(node)
      # Check that mirror considers this the active (and therefor valid) chaintip
      chaintips = node.mirror_client.getchaintips
      if block_hash == chaintips.filter { |t| t['status'] == 'active' }.first['hash']
        update marked_valid_by: marked_valid_by | [node.id]
        undo_rollback!(node)
      else
        # If something went wrong, first ask the node to reconsider all "invalid" blocks,
        # to avoid false alarm:
        node.mirror_client.getchaintips.filter { |tip| tip['status'] == 'invalid' }.each do |tip|
          Rails.logger.info "Reconsider block #{tip['hash']}"
          node.mirror_client.reconsiderblock(tip['hash']) # This is a blocking call
          sleep 1 # But wait anyway
        end
      end
    rescue StandardError => e
      # If anything went wrong with make_active_on_mirror! or undo_rollback!
      Rails.logger.error "Rescued: #{e.inspect}"
      Rails.logger.error 'Restoring node before bailing out...'
      Rails.logger.info 'Resume p2p networking...'
      node.mirror_client.setnetworkactive(true)
      # Have node return to tip, by reconsidering all invalid chaintips
      node.mirror_client.getchaintips.filter { |tip| tip['status'] == 'invalid' }.each do |tip|
        Rails.logger.info "Reconsider block #{tip['hash']}"
        node.mirror_client.reconsiderblock(tip['hash']) # This is a blocking call
        sleep 1 # But wait anyway
      end
      Rails.logger.info 'Node restored'
      # Give node some time to catch up:
      node.update mirror_rest_until: 60.seconds.from_now
      raise # continue throwing error
    end

    # Check if this block is still considered invalid:
    if chaintips.filter { |t| t['status'] == 'invalid' && t['hash'] == block_hash }.count.positive?
      update marked_invalid_by: marked_invalid_by | [node.id]
      Rails.logger.info "Mirror node #{node.id} block #{block_hash} invalid"
      return nil
    end

    Rails.logger.info 'Resume p2p networking...'
    node.mirror_client.setnetworkactive(true)
    # Leave node alone for a bit:
    node.update mirror_rest_until: 60.seconds.from_now
    nil
  end

  class << self
    def to_csv
      attributes = %w[height block_hash timestamp mediantime work version tx_count size pool total_fee
                      template_txs_fee_diff]

      CSV.generate(headers: true) do |csv|
        csv << attributes

        order(height: :desc).each do |block|
          csv << attributes.map { |attr| block.send(attr) }
        end
      end
    end

    def max_inflation(height)
      interval = height / 210_000
      reward = 50 * 100_000_000
      reward >> interval
    end

    def create_or_update_with(block_info, _use_mirror, node, mark_valid)
      block = Block.find_or_create_by(
        block_hash: block_info['hash'],
        coin: node.coin,
        height: block_info['height']
      )
      tx_count = extract_tx_count(block_info)

      Rails.logger.error "Missing version for #{node.coin.to_s.upcase} #{block.block_hash} (#{block.height}) from #{node.name_with_version}}" if block_info['version'].nil?

      block.update(
        mediantime: block_info['mediantime'],
        timestamp: block_info['time'],
        work: block_info['chainwork'],
        version: block_info['version'],
        tx_count: tx_count,
        size: block_info['size'],
        first_seen_by: node,
        headers_only: false
      )
      if mark_valid.present?
        if mark_valid == true
          block.update marked_valid_by: [node.id]
        else
          block.update marked_invalid_by: [node.id]
        end
      end
      # Set pool:
      Node.set_pool_for_block!(node.coin.to_sym, block, block_info)

      # Fetch transactions if there was a stale block recently
      if StaleCandidate.where(coin: node.coin).where('height >= ?',
                                                     block.height - StaleCandidate::DOUBLE_SPEND_RANGE).count.positive?
        block.fetch_transactions!
      end
      block.expire_stale_candidate_cache
      block
    end

    def create_headers_only(node, height, block_hash)
      throw 'node missing' if node.nil?
      throw 'height missing' if height.nil?
      begin
        block = Block.create(
          coin: node.coin,
          height: height,
          block_hash: block_hash,
          headers_only: true,
          first_seen_by: node,
          tx_count: nil
        )
        # Fetch headers
        block.fetch_header!(node)
        # TODO: connect longer branches to common ancestor (fetch more headers if needed)
        block
      rescue ActiveRecord::RecordNotUnique
        raise unless Rails.env.production?

        Block.find_by(node.coin, block_hash: block_hash)
      end
    end

    def extract_tx_count(block_info)
      if block_info.key?('nTx')
        block_info['nTx']
      elsif block_info['tx'].is_a?(Array)
        block_info['tx'].count
      end
    end

    def coinbase_message(tx)
      throw 'transaction missing' if tx.nil?
      return nil if tx['vin'].nil? || tx['vin'].blank?

      coinbase = nil
      tx['vin'].each do |vin|
        coinbase = vin['coinbase']
        break if coinbase.present?
      end
      throw 'not a coinbase' if coinbase.nil?
      [coinbase].pack('H*')
    end

    def pool_from_coinbase_tx(tx)
      throw 'transaction missing' if tx.nil?

      message = coinbase_message(tx)
      return nil if message.nil?

      Pool.all.find_each do |pool|
        return pool.name if message.force_encoding('UTF-8').include?(pool.tag)
      end
      nil
    end

    def match_missing_pools!(coin, limit)
      Block.where(coin: coin, pool: nil).order(height: :desc).limit(limit).each do |b|
        Node.set_pool_for_block!(coin, b)
      end
    end

    def find_or_create_block_and_ancestors!(hash, node, use_mirror, mark_valid)
      raise 'block hash missing' if hash.blank?

      # Not atomic and called very frequently, so sometimes it tries to insert
      # a block that was already inserted. In that case try again, so it updates
      # the existing block instead.
      client = use_mirror ? node.mirror_client : node.client
      begin
        block = Block.find_by(block_hash: hash)

        if block.nil?
          if node.client_type.to_sym == :libbitcoin
            block_info = client.getblockheader(hash)
          else
            begin
              block_info = node.getblock(hash, 1, use_mirror)
            rescue BitcoinUtil::RPC::BlockPrunedError
              block_info = client.getblockheader(hash)
            end
          end
          block = Block.create_or_update_with(block_info, use_mirror, node, mark_valid)
        end

        block.find_ancestors!(node, use_mirror, mark_valid)
      rescue ActiveRecord::RecordNotUnique
        raise unless Rails.env.production?

        retry
      end
      block
    end

    # This method returns nil if at any point the mirror node can't be reached or is restarting
    def find_missing(coin, max_depth, patience)
      throw "Invalid coin argument #{coin}" unless Rails.configuration.supported_coins.include?(coin)

      # Find recent headers_only blocks
      tip_height = Block.where(coin: coin).maximum(:height)
      blocks = Block.where(coin: coin, headers_only: true).where('height >= ?',
                                                                 tip_height - max_depth).order(height: :asc)
      return if blocks.count.zero?

      getblockfrompeer_blocks = []
      # Ensure the most recent node supports getblockfrompeer or is patched:
      # https://github.com/BitMEXResearch/bitcoin/pull/2
      gbfp_node = coin == :btc ? Node.with_mirror(coin).first : nil
      gbfp_node = nil if Rails.env.test? # TODO: add test coverage, maybe after v22.0 release

      blocks.each do |block|
        block_info = nil
        raw_block = nil
        # Try to fetch from other nodes.
        nodes_to_try = case coin.to_sym
                       when :btc
                         Node.bitcoin_core_by_version
                       when :tbtc
                         Node.testnet_by_version
                       end
        # Keep track of the original first seen node
        # To make mocks easier, require that it's part of nodes_to_try:
        originally_seen_by = nodes_to_try.find { |node| node.id == block.first_seen_by_id }
        # Don't bother checking nodes for old blocks; they won't ask for them
        if tip_height - block.height < 10
          nodes_to_try.each do |node|
            block_info = node.getblock(block.block_hash, 1)
            raw_block = node.getblock(block.block_hash, 0)
            block.update_fields(block_info)
            block.update headers_only: false, first_seen_by: node
            Node.set_pool_for_block!(coin, block, block_info)
            break
          rescue BitcoinUtil::RPC::BlockNotFoundError, BitcoinUtil::RPC::TimeOutError # rubocop:disable Lint/SuppressedException
          end

          if raw_block.present?
            # Feed block to original node
            originally_seen_by.client.submitblock(raw_block, block.block_hash) if originally_seen_by.present? && !(originally_seen_by.core? && originally_seen_by.version < 130_100)
            # Feed block to node with transaction index:
            begin
              Node.first_with_txindex(coin.to_sym, :core).client.submitblock(raw_block, block.block_hash)
            rescue BitcoinUtil::RPC::NoTxIndexError # rubocop:disable Lint/SuppressedException
            end
          end
        end

        # Try getblockfrompeer on the gbfp_node (mirror) node
        next if raw_block.present?
        next if gbfp_node.nil?

        # Does the gbfp mirror node have the header?
        begin
          gbfp_node.getblockheader(block.block_hash, true, true)
        rescue BitcoinUtil::RPC::BlockNotFoundError
          # Feed it the block header
          next if originally_seen_by.nil?

          raw_block_header = originally_seen_by.getblockheader(block.block_hash, false)
          begin
            # This requires blocks to be processed in ascending height order
            gbfp_node.mirror_client.submitheader(raw_block_header)
          rescue BitcoinUtil::RPC::PreviousHeaderMissing
            # TODO: call submitheader multiple times if needed
            next
          end
        rescue BitcoinUtil::RPC::NodeInitializingError
          next
        end
        peers = gbfp_node.mirror_client.getpeerinfo
        # Ask each peer for the block
        Rails.logger.info "Request block #{block.block_hash} (#{block.height}) from peers #{peers.collect do |peer|
                                                                                              peer['id']
                                                                                            end.join(', ')}"
        peers.each do |peer|
          gbfp_node.mirror_client.getblockfrompeer(block.block_hash, peer['id'])
        rescue BitcoinUtil::RPC::Error
          # immedidately disconnect
          begin
            gbfp_node.mirror_client.disconnectnode('', peer['id'])
          rescue BitcoinUtil::RPC::PeerNotConnected
            # Ignore if already disconnected for some reason
          end
        end
        getblockfrompeer_blocks << block
      end

      if getblockfrompeer_blocks.count.positive?
        Rails.logger.info "Wait #{patience} seconds and check if the mirror node retrieved any of the #{getblockfrompeer_blocks.count} blocks..."
        # Wait for getblockfrompeer responses
        sleep patience

        found_block = false
        raw_block = nil
        getblockfrompeer_blocks.each do |block|
          raw_block = gbfp_node.getblock(block.block_hash, 0, true)
          Rails.logger.info "Retrieved #{block.coin.upcase} block #{block.block_hash} (#{block.height}) on the mirror node"
          found_block = true
          # Feed block to original node
          if block.first_seen_by.present? && !(block.first_seen_by.core? && block.first_seen_by.version < 130_100)
            Rails.logger.info "Submit block #{block.block_hash} (#{block.height}) to #{block.first_seen_by.name_with_version}"
            block.first_seen_by.client.submitblock(raw_block, block.block_hash)
            block_info = gbfp_node.getblock(block.block_hash, 1, true)
            block.update_fields(block_info)
            block.update headers_only: false
            Node.set_pool_for_block!(coin, block, block_info)
          end
        rescue BitcoinUtil::RPC::TimeOutError
          Rails.logger.error "Timeout on mirror node while trying to fetch #{block.block_hash} (#{block.height})"
        rescue BitcoinUtil::RPC::BlockNotFoundError
          Rails.logger.info "Block #{block.block_hash} (#{block.height}) not found on the mirror node"
        rescue BitcoinUtil::RPC::BlockPrunedError
          Rails.logger.info "Block #{block.block_hash} (#{block.height}) was pruned from the mirror node"
        end
      end

      if !found_block && !gbfp_node.nil?
        # Disconnect all peers if we didn't get any block

        peers = gbfp_node.mirror_client.getpeerinfo
        peers.each do |peer|
          gbfp_node.mirror_client.disconnectnode('', peer['id'])
        rescue BitcoinUtil::RPC::PeerNotConnected
          # Ignore if already disconnected, e.g. by us above
        end

      end
    rescue BitcoinUtil::RPC::NodeInitializingError, BitcoinUtil::RPC::ConnectionError
      nil
    end

    def process_templates!(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      min_height = BlockTemplate.where(coin: coin).minimum(:height)
      Block.where(coin: coin, template_txs_fee_diff: nil).where('height >= ?',
                                                                min_height).where.not(total_fee: nil).find_each(&:set_template_diff!)
    end
  end
end
