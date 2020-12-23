require 'csv'

class Block < ApplicationRecord
  MINIMUM_BLOCK_HEIGHTS = {
    btc: Rails.env.test? ? 0 : 500000, # Mid December 2017, around Lightning network launch
    tbtc: 1600000,
    bch: 581000
  }

  class RollbackError < StandardError; end

  has_many :children, class_name: 'Block', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Block', foreign_key: 'parent_id', optional: true
  has_many :invalid_blocks, dependent: :destroy
  belongs_to :first_seen_by, class_name: 'Node', foreign_key: 'first_seen_by_id', optional: true
  has_many :tx_outsets, dependent: :destroy
  has_one :inflated_block
  has_many :maybe_uncoop_transactions, dependent: :destroy
  has_many :penalty_transactions, dependent: :destroy
  has_many :sweep_transactions, dependent: :destroy
  has_many :transactions, dependent: :destroy
  enum coin: [:btc, :bch, :bsv, :tbtc]

  # Used to trigger and restore reorgs on the mirror node
  attr_accessor :invalidated_block_hashes
  after_initialize :set_invalidated_block_hashes

  def as_json(options = nil)
    super({ only: [:id, :coin, :height, :timestamp, :created_at, :pool, :tx_count, :size] }.merge(options || {})).merge({
      hash: block_hash,
      work: log2_pow,
      first_seen_by: first_seen_by ? {
        id: first_seen_by.id,
        name_with_version: first_seen_by.name_with_version
      } : nil
    })
  end

  def self.to_csv
    attributes = %w{height block_hash timestamp mediantime work version tx_count size pool }

    CSV.generate(headers: true) do |csv|
      csv << attributes

      order(height: :desc).each do |block|
        csv << attributes.map{ |attr| block.send(attr) }
      end
    end
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
    ("%.32b" % (self.version & ~0xe0000000)).split("").drop(3).reverse().collect{|s|s.to_i}
  end

  # https://bitcoin.stackexchange.com/a/9962
  def max_inflation
    interval = self.height / 210000
    reward = 50 * 100000000
    return reward >> interval # as opposed to (reward / 2**interval)
  end

  def descendants(depth_limit=nil)
    block_hash = self.block_hash
    height = self.height
    coin = self.coin
    max_height = depth_limit.nil? ? 10000000 : height + depth_limit
    # Constrain query by coin and minimum height to reduce memory usage
    Block.where(coin: coin).where("height > ? AND height <= ?", height, max_height).join_recursive {
      start_with(block_hash: block_hash).
      connect_by(id: :parent_id).
      order_siblings(:work)
    }
  end

  # Find branch point with common ancestor, and return the start of the branch,
  # i.e. the block after the common ancenstor
  def branch_start(other_block)
    raise "same block" if self == other_block
    candidate_branch_start = self
    while !candidate_branch_start.nil?
      if candidate_branch_start.parent.descendants.include? other_block
        raise "same branch" if self == candidate_branch_start
        return candidate_branch_start
      end
      candidate_branch_start = candidate_branch_start.parent
    end
    raise "dead end"
  end

  def fetch_transactions!
    Rails.logger.debug "Fetch transactions at height #{ self.height } (#{ self.block_hash })..."
    if self.transactions.count == 0 && !self.pruned && !self.headers_only
      # TODO: if node doesn't have getblock equivalent (e.g. libbitcoin), try other nodes
      # Workaround for test framework, needed in order to mock first_seen_by
      this_block = Rails.env.test? ? Block.find_by(block_hash: self.block_hash) : self
      begin
        node = this_block.first_seen_by
        # getblock argument verbosity 2 was added in v0.16.0
        # Knots doesn't return the transaction hash
        if node.nil? || (node.core? && node.version < 160000) || node.libbitcoin? || node.knots? || node.btcd? || node.bcoin?
          node = Node.newest_node(this_block.coin.to_sym)
        end
        block_info = node.getblock(self.block_hash, 2)
      rescue Node::BlockPrunedError
        self.update pruned: true
        return
      end
      throw "Missing transaction data for #{ self.coin.upcase } block #{ self.height } (#{ self.block_hash }) on #{ node.name_with_version }" if block_info["tx"].nil?
      block_info["tx"].each_with_index do |tx, i|
        self.transactions.create(
          is_coinbase: i == 0,
          tx_id: tx["txid"],
          raw: tx["hex"],
          amount: tx["vout"].sum { |vout| vout["value"] }
        )
      end
    end
  end

  def find_ancestors!(node, use_mirror, mark_valid, until_height = nil)
    block_id = self.id
    block_ids = []
    client = use_mirror ? node.mirror_client : node.client
    loop do
      block_ids.append(block_id)
      block = Block.find(block_id)
      # Prevent new instances from going too far back:
      minimum_height = node.client.class == BitcoinClientMock ? 560176 : Block::MINIMUM_BLOCK_HEIGHTS[block.coin.to_sym]
      break if block.height == 0 || block.height <= minimum_height
      break if until_height && block.height == until_height
      parent = block.parent
      if parent.nil?
        if node.client_type.to_sym == :libbitcoin
          block_info = client.getblockheader(block.block_hash)
        else
          begin
            block_info = node.getblock(block.block_hash, 1, use_mirror)
          rescue Node::BlockPrunedError
            block_info = client.getblockheader(block.block_hash)
          end
        end
        throw "block_info unexpectedly empty" unless block_info.present?
        parent = Block.find_by(block_hash: block_info["previousblockhash"])
        block.update parent: parent
      end
      if parent.present?
        break if until_height.nil? && parent.connected
      else
        # Fetch parent block:
        break if !self.id
        puts "Fetch intermediate block at height #{ block.height - 1 }" unless Rails.env.test?
        if node.client_type.to_sym == :libbitcoin
          block_info = client.getblockheader(block_info["previousblockhash"])
        else
          begin
            block_info = node.getblock(block_info["previousblockhash"], 1, use_mirror)
          rescue Node::BlockPrunedError
            block_info = client.getblockheader(block_info["previousblockhash"])
          end
        end

        parent = Block.create_or_update_with(block_info, use_mirror, node, mark_valid)
        block.update parent: parent
      end
      block_id = parent.id
    end
    # Go back up to the tip to mark blocks as connected
    return if until_height && !Block.find(block_id).connected
    Block.where("id in (?)", block_ids).update connected: true
  end

  def summary(time: false, first_seen_by: false)
    result = block_hash + " ("
    if size.present?
      result += "#{ (size / 1000.0 / 1000.0).round(2) } MB, "
    end
    if time && timestamp.present?
      result += "#{ Time.at(timestamp).utc.strftime("%H:%M:%S") } by "
    end
    result += "#{ pool.present? ? pool : "unknown pool" }"
    if first_seen_by && self.first_seen_by.present?
      result += ", first seen by #{ self.first_seen_by.name_with_version }"
    end
    return result + ")"
  end

  def block_and_descendant_transaction_ids(depth_limit)
    ([self] + self.descendants(depth_limit)).collect{|b| b.transactions.where(is_coinbase: false).select(:tx_id)}.flatten.collect{|tx| tx.tx_id}.uniq
  end

  # Preloads tx_id, raw and amount
  def block_and_descendant_transactions(depth_limit)
    ([self] + self.descendants(depth_limit)).collect{|b| b.transactions.where(is_coinbase: false).select(:tx_id, :raw, :amount)}.flatten
  end

  def update_fields(block_info)
    self.work = block_info["chainwork"]
    self.mediantime = block_info["mediantime"]
    self.timestamp = block_info["time"]
    self.work = block_info["chainwork"]
    self.version = block_info["version"]
    self.tx_count = Block.extract_tx_count(block_info)
    self.size = block_info["size"]
    # Connect to parent if available:
    if self.parent.nil?
      self.parent = Block.find_by(block_hash: block_info["previousblockhash"])
      self.connected = self.parent.nil? ? false : self.parent.connected
    end
    self.save if self.changed?
  end

  def fetch_header!(node)
    begin
      block_info = node.getblockheader(self.block_hash)
      update_fields(block_info)
    rescue Node::MethodNotFoundError
      # Ignore old clients that don't support getblockheader
      return false
    rescue Node::BlockNotFoundError
      # Try another node and/or try again later
      return false
    rescue Node::TimeOutError
      # Try another node and/or try again later
      return false
    end
    return true
  end

  def self.create_or_update_with(block_info, use_mirror, node, mark_valid)

    block = Block.find_or_create_by(
       block_hash: block_info["hash"],
       coin: node.coin,
       height: block_info["height"]
    )
    tx_count = extract_tx_count(block_info)

    block.update(
      mediantime: block_info["mediantime"],
      timestamp: block_info["time"],
      work: block_info["chainwork"],
      version: block_info["version"],
      tx_count:  tx_count,
      size: block_info["size"],
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
   if StaleCandidate.where(coin: node.coin).where("height >= ?", block.height - StaleCandidate::DOUBLE_SPEND_RANGE).count > 0
     block.fetch_transactions!
   end
   block.expire_stale_candidate_cache
   return block
  end

  def self.create_headers_only(node, height, block_hash)
    throw "node missing" if node.nil?
    throw "height missing" if height.nil?
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
      # * except for BCHN nodes, which don't support getblockheader outside main chain:
      #   https://gitlab.com/bitcoin-cash-node/bitcoin-cash-node/-/issues/178
      unless node.name == "BCHN"
        block.fetch_header!(node)
      end
      # TODO: connect longer branches to common ancestor (fetch more headers if needed)
      return block
    rescue ActiveRecord::RecordNotUnique
      raise unless Rails.env.production?
      return Block.find_by(node.coin, block_hash: block_hash)
    end

  end

  def self.extract_tx_count(block_info)
    block_info.key?("nTx") ? block_info["nTx"] :
               block_info["tx"].kind_of?(Array) ? block_info["tx"].count :
               nil
  end

  def self.coinbase_message(tx)
    throw "transaction missing" if tx.nil?
    return nil if tx["vin"].nil? || tx["vin"].blank?
    coinbase = nil
    tx["vin"].each do |vin|
      coinbase = vin["coinbase"]
      break if coinbase.present?
    end
    throw "not a coinbase" if coinbase.nil?
    return [coinbase].pack('H*')
  end

  def self.pool_from_coinbase_tx(tx)
    throw "transaction missing" if tx.nil?
    pools_ascii = {
      "--Nug--" => "shawnp0wers",
      "/$Mined by 7pool.com/" => "7pool",
      "/58coin.com/" => "58COIN",
      "/A-XBT/" => "A-XBT",
      "/AntPool/" => "Antpool",
      "/BATPOOL/" => "BATPOOL",
      "/BCMonster/" => "BCMonster",
      "Binance" => "Binance",
      "BTC.COM" => "BTC.com",
      "BTC.TOP/" => "BTC.TOP",
      "/BTCC/" => "BTCC Pool",
      "/BitClub Network/" => "BitClub Network",
      "/BitFury/" => "BitFury",
      "/Bitcoin-India/" => "Bitcoin India",
      "/Bitcoin-Russia.ru/" => "BitcoinRussia",
      "/Bitdeer/" => "Bitdeer",
      "/Bitfury/" => "BitFury",
      "/Bixin/" => "Bixin",
      "/CANOE/" => "CANOE",
      "/ConnectBTC - Home for Miners/" => "ConnectBTC",
      "/DCExploration/" => "DCExploration",
      "/DPOOL.TOP/" => "DPOOL",
      "/HaoBTC/" => "Bixin",
      "/hash.okkong.com/" => "OKKong",
      "/HuoBi/" => "HuoBi",
      "/HotPool/" => "HotPool",
      "/LongBOXShortTheWorld/" => "LongBOXShortTheWorld",
      "/Mined by HashBX.io/" => "HashBX",
      "/Nexious/" => "Nexious",
      "/NiceHashSolo" => "NiceHash Solo",
      "/RigPool.com/" => "RigPool",
      "Sigmapool" => "Sigmapool",
      "/ViaBTC/" => "ViaBTC",
      "/WATERHOLE.IO/" => "Waterhole",
      "/agentD/" => "digitalBTC",
      "/bravo-mining/" => "Bravo Mining",
      "/ckpool.org/" => "CKPool",
      "/haominer/" => "Haominer",
      "/haozhuzhu/" => "HAOZHUZHU",
      "/mined by gbminers/" => "GBMiners",
      "/mined by poopbut/" => "MiningKings",
      "/MiningCity/" => "MiningCity",
      "/Mining-Dutch" => "Mining-Dutch",
      "/mtred/" => "Mt Red",
      "/NovaBlock" => "NovaBlock",
      "/phash.cn/" => "PHash.IO",
      "/phash.io/" => "PHash.IO",
      "/pool34/" => "21 Inc.",
      "/poolin.com/" => "Poolin",
      "/prohashing.com" => "Prohashing",
      "/slush/" => "SlushPool",
      "/solo.ckpool.org/" => "Solo CKPool",
      "/SpiderPool" => "SpiderPool",
      "50BTC" => "50BTC",
      "ASICMiner" => "ASICMiner",
      "BTC Guild" => "BTC Guild",
      "BTCChina Pool" => "BTCC Pool",
      "BTCChina.com" => "BTCC Pool",
      "BW Pool" => "BW.COM",
      "BitMinter" => "BitMinter",
      "Bitalo" => "Bitalo",
      "Bitsolo Pool" => "Bitsolo",
      "/Buffett/" => "Buffett",
      "CoinLab" => "CoinLab",
      "^easy2" => "WaYi",
      "EMC" => "EclipseMC",
      "Eligius" => "Eligius",
      "Give-Me-Coins" => "Give Me Coins",
      "HASHPOOL" => "HASHPOOL",
      "HHTT" => "HHTT",
      "Kano" => "KanoPool",
      "KnCMiner" => "KnCMiner",
      "/lubian.com/" => "Lubian",
      "MaxBTC" => "MaxBTC",
      "Mined By 175btc.com" => "175btc",
      "Mined by 1hash.com" => "1Hash",
      "Mined by AntPool" => "Antpool",
      "Mined by MultiCoin.co" => "MultiCoin.co",
      "Rawpool.com" => "Rawpool.com",
      "SigmaPool.com" => "SigmaPool.com",
      "SBIC" => "SBI Crypto",
      "TBDice" => "TBDice",
      "Triplemining.com" => "TripleMining",
      "bcpool.io" => "bcpool.io",
      "bitcoinaffiliatenetwork.com" => "Bitcoin Affiliate Network",
      "bitparking" => "Bitparking",
      "btcchina.com" => "BTCC Pool",
      "btcserv" => "BTCServ",
      "by polmine.pl" => "Polmine",
      "bypmneU" => "Polmine",
      "cointerra" => "Cointerra",
      "ghash.io" => "GHash.IO",
      "megabigpower.com" => "MegaBigPower",
      "mmpool" => "mmpool",
      "myBTCcoin Pool" => "myBTCcoin Pool",
      "nmcbit.com" => "NMCbit",
      "/www.okex.com/" => "OKEx",
      "ozco.in" => "OzCoin",
      "ozcoin" => "OzCoin",
      "pool.bitcoin.com" => "Bitcoin.com",
      "simplecoin" => "simplecoin.us",
      "st mining corp" => "ST Mining Corp",
      "/1THash" => "1THash",
      "triplemining" => "TripleMining",
      "viabtc.com deploy" => "ViaBTC",
      "xbtc.exx.com&bw.com" => "xbtc.exx.com&bw.com",
      "/Ukrpool.com/" => "Ukrpool",
      "yourbtc.net" => "Yourbtc.net"
    }

    pools_utf8 = {
        "🐟" => "F2Pool"
    }

    message = coinbase_message(tx)
    return nil if message.nil?

    pools_ascii.each do |match, name|
      return name if message.downcase.include?(match.downcase)
    end
    message_utf8 = message.force_encoding('UTF-8')
    pools_utf8.each do |match, name|
      return name if message_utf8.include?(match)
    end
    return nil
  end

  def self.match_missing_pools!(coin, n)
    Block.where(coin: coin, pool: nil).order(height: :desc).limit(n).each do |b|
      Node.set_pool_for_block!(coin, b)
    end
  end

  def self.find_or_create_block_and_ancestors!(hash, node, use_mirror, mark_valid)
    raise "block hash missing" unless hash.present?
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
          rescue Node::BlockPrunedError
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
    return block
  end

  def self.find_missing(coin, max_depth, patience)
    throw "Invalid coin argument #{ coin }" unless Node::SUPPORTED_COINS.include?(coin)
    Node.where(mirror_rpchost: "").update_all mirror_rpchost: nil

    # Find recent headers_only blocks
    tip_height = Block.where(coin: coin).maximum(:height)
    blocks = Block.where(coin: coin, headers_only: true).where("height >= ?", tip_height - max_depth).order(height: :asc)
    return if blocks.count == 0

    getblockfrompeer_blocks = []
    special = Node.find_by(coin: coin, special: true)

    blocks.each do |block|
      block_info = nil
      raw_block = nil
      # Try to fetch from other nodes.
      nodes_to_try = case coin.to_sym
      when :btc
        Node.bitcoin_core_by_version
      when :tbtc
        Node.testnet_by_version
      when :bch
        Node.bch_by_version
      end
      # Keep track of the original first seen node
      # To make mocks easier, require that it's part of nodes_to_try:
      originally_seen_by = nodes_to_try.find { |node| node.id == block.first_seen_by_id }
      # Don't bother checking nodes for old blocks; they won't ask for them
      if tip_height - block.height < 10
        nodes_to_try.each do |node|
          begin
            block_info = node.getblock(block.block_hash, 1)
            raw_block = node.getblock(block.block_hash, 0)
            block.update_fields(block_info)
            block.update headers_only: false, first_seen_by: node
            Node.set_pool_for_block!(coin, block, block_info)
            break
          rescue Node::BlockNotFoundError
          rescue Node::TimeOutError
          end
        end

        if raw_block.present?
          # Feed block to original node
          if originally_seen_by.present?
            # Except for pre-segwit nodes
            unless originally_seen_by.core? && originally_seen_by.version < 130100
              originally_seen_by.client.submitblock(raw_block)
            end
          end
          # Feed block to node with transaction index:
          begin
            Node.first_with_txindex(coin.to_sym, :core).client.submitblock(raw_block)
          rescue Node::NoTxIndexError
          end
        end
      end

      # Try getblockfrompeer on the special node
      unless raw_block.present?
        next if special.nil?
        # Does the special node have the header?
        begin
          special.getblockheader(block.block_hash)
        rescue Node::BlockNotFoundError
          # Feed it the block header
          next if originally_seen_by.nil?
          raw_block_header = originally_seen_by.getblockheader(block.block_hash, false)
          # This requires blocks to be processed in ascending height order
          special.client.submitheader(raw_block_header)
        rescue BitcoinClient::NodeInitializingError
          next
        end
        peers = special.client.getpeerinfo
        # Ask each peer for the block
        Rails.logger.debug "Request block #{ block.block_hash } (#{ block.height }) from peers #{ peers.collect{ |peer| peer["id"] }.join(", ")}"
        peers.each do |peer|
          begin
            special.client.getblockfrompeer(block.block_hash, peer["id"])
          rescue BitcoinClient::Error
            # immedidately disconnect
            begin
              special.client.disconnectnode("", peer["id"])
            rescue BitcoinClient::PeerNotConnected
              # Ignore if already disconnected for some reason
            end
          end
        end
        getblockfrompeer_blocks << block
      end
    end

    if getblockfrompeer_blocks.count > 0
      Rails.logger.debug "Wait #{ patience } seconds and check if the special node retrieved any of the #{ getblockfrompeer_blocks.count } blocks..."
      # Wait for getblockfrompeer responses
      sleep patience

      found_block = false
      raw_block = nil
      getblockfrompeer_blocks.each do |block|
        begin
          raw_block = special.getblock(block.block_hash, 0)
          Rails.logger.info "Retrieved block #{ block.block_hash } (#{ block.height }) on the special node"
          found_block = true
          # Feed block to original node
          if block.first_seen_by.present?
            # Except for pre-segwit nodes
            unless block.first_seen_by.core? && block.first_seen_by.version < 130100
              Rails.logger.info "Submit block #{ block.block_hash } (#{ block.height }) to #{ block.first_seen_by.name_with_version }"
              block.first_seen_by.client.submitblock(raw_block)
              block_info = special.getblock(block.block_hash, 1)
              block.update_fields(block_info)
              block.update headers_only: false
              Node.set_pool_for_block!(coin, block, block_info)
            end
          end
        rescue Node::BlockNotFoundError
          Rails.logger.debug "Block #{ block.block_hash } (#{ block.height }) not found on the special node"
        rescue Node::BlockPrunedError
          Rails.logger.debug "Block #{ block.block_hash } (#{ block.height }) was pruned from the special node"
        end
      end
    end

    if !found_block && !special.nil?
      # Disconnect all peers if we didn't get any block
      peers = special.client.getpeerinfo;
      peers.each do |peer|
        begin
          special.client.disconnectnode("", peer["id"])
        rescue BitcoinClient::PeerNotConnected
          # Ignore if already disconnected, e.g. by us above
        end
      end
    end
  end

  def expire_stale_candidate_cache
    StaleCandidate.where(coin: self.coin).each do |c|
      if self.height - c.height <= StaleCandidate::STALE_BLOCK_WINDOW
        c.expire_cache
      end
    end
  end

  def set_invalidated_block_hashes
    @invalidated_block_hashes = []
  end

  def make_active_on_mirror!(node)
    # Invalidate new blocks, including any forks we don't know of yet
    Rails.logger.debug "Roll back the chain to #{ self.block_hash } (#{ self.height }) on #{ node.name_with_version }..."
    tally = 0
    while(active_tip = node.get_mirror_active_tip; active_tip.present? && self.block_hash != active_tip["hash"])
      if tally > (Rails.env.test? ? 2 : 100)
        throw_unable_to_roll_back!(node)
      elsif tally > 0
        Rails.logger.debug "Fetch blocks for any newly activated chaintips on #{ node.name_with_version }..."
        node.poll_mirror!
        self.reload
      end
      Rails.logger.debug "Current tip #{ active_tip["hash"] } (#{ active_tip["height"] }) on #{ node.name_with_version }"
      blocks_to_invalidate = []
      active_tip_block = Block.find_by!(block_hash: active_tip["hash"])
      if self.height == active_tip["height"]
        Rails.logger.debug "Invalidate tip to jump to another fork"
        blocks_to_invalidate.append(active_tip_block)
      else
        Rails.logger.debug "Check if active chaintip (#{ active_tip["height"] }) descends from target block (#{ self.height }), otherwise invalidate the active chain..."
        if !self.descendants.include? active_tip_block
          blocks_to_invalidate.append(active_tip_block.branch_start(self))
        end
        # Invalidate all child blocks we know of, if the node knows them
        self.children.each do |child_block|
          begin
            node.mirror_client.getblockheader(child_block.block_hash)
          rescue BitcoinClient::Error
            Rails.logger.error "Skip invalidation of #{ child_block.block_hash } (#{ child_block.height }) on #{ node.name_with_version } because mirror node doesn't have it"
            next
          end
          unless @invalidated_block_hashes.include?(child_block.block_hash)
            blocks_to_invalidate.append(child_block)
          end
        end
      end
      # Stop if there are no new blocks to invalidate
      if (blocks_to_invalidate.collect { |b| b.block_hash } - @invalidated_block_hashes).empty?
        Rails.logger.error "Nothing to invalidate on #{ node.name_with_version }"
        throw_unable_to_roll_back!(node, blocks_to_invalidate, @invalidated_block_hashes)
      end
      blocks_to_invalidate.each do |block|
        @invalidated_block_hashes.append(block.block_hash)
        Rails.logger.debug "Invalidate block #{ block.block_hash } (#{ block.height }) on #{ node.name_with_version }"
        node.mirror_client.invalidateblock(block.block_hash) # This is a blocking call
      end
      tally += 1
      # Give node some time to update its internals. There were occasional
      # failures where the gettxoutsetinfo below would be applied to the
      # child block, despite checks against that.
      sleep 3
    end

    throw "No active tip left after rollback on #{ node.name_with_version }. Was expecting #{ self.block_hash } (#{ self.height })" unless active_tip.present?
    throw "Unexpected active tip hash #{ active_tip["hash"] } (#{ active_tip["height"] }) instead of #{ self.block_hash } (#{ self.height }) on #{ node.name_with_version }" unless active_tip["hash"] == self.block_hash

  end

  def throw_unable_to_roll_back!(node, blocks_to_invalidate = nil, invalidated_block_hashes = nil)
    error = "Unable to roll active #{ self.coin.upcase } chaintip to #{ self.block_hash } (#{ self.height }) on node #{ node.id } #{ node.name_with_version }"
    error += "\nChaintips: #{ node.mirror_client.getchaintips.filter{|t| t["height"] > self.height - 100 }.collect { |t| "#{ t["hash"] } (#{ t["height"] })=#{ t["status"] }" }.join(", ") }"
    if !invalidated_block_hashes.nil?
      error += "\nInvalidated blocks: #{ invalidated_block_hashes.collect { |b| "#{ b.block_hash } (#{ b.height })" }.join(", ")}"
    end
    if !blocks_to_invalidate.nil?
      error += "\nBlocks to invalidate: #{ blocks_to_invalidate.collect { |b| "#{ b.block_hash } (#{ b.height })" }.join(", ")}"
    end
    raise RollbackError.new(error)
  end

end
