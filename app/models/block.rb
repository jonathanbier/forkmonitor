MINIMUM_BLOCK_HEIGHT = 560176 # Tests need to be adjusted if this number is increased

class Block < ApplicationRecord
  has_many :children, class_name: 'Block', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Block', foreign_key: 'parent_id', optional: true
  has_many :invalid_blocks
  belongs_to :first_seen_by, class_name: 'Node', foreign_key: 'first_seen_by_id', optional: true
  has_many :tx_outsets
  has_one :inflated_block
  enum coin: [:btc, :bch, :bsv, :tbtc]

  def as_json(options = nil)
    super({ only: [:height, :timestamp] }.merge(options || {})).merge({
      id: id,
      hash: block_hash,
      timestamp: timestamp,
      work: log2_pow,
      pool: pool,
      tx_count: tx_count,
      size: size,
      first_seen_by: first_seen_by ? {
        id: first_seen_by.id,
        name_with_version: first_seen_by.name_with_version
      } : nil})
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

  def find_ancestors!(node, until_height = nil)
    # Prevent new instances from going too far back:
    block_id = self.id
    loop do
      block = Block.find(block_id)
      return if until_height ? block.height == until_height : block.height <= MINIMUM_BLOCK_HEIGHT
      parent = block.parent
      if parent.nil?
        if node.client_type.to_sym == :libbitcoin
          block_info = node.client.getblockheader(block.block_hash)
        else
          block_info = node.client.getblock(block.block_hash)
        end
        parent = Block.find_by(block_hash: block_info["previousblockhash"])
        block.update parent: parent
      end
      if parent.present?
        return if until_height.nil?
      else
        # Fetch parent block:
        break if !self.id
        puts "Fetch intermediate block at height #{ block.height - 1 }" unless Rails.env.test?
        if node.client_type.to_sym == :libbitcoin
          block_info = node.client.getblockheader(block_info["previousblockhash"])
        else
          block_info = node.client.getblock(block_info["previousblockhash"])
        end

        parent = Block.create_with(block_info, node)
        block.update parent: parent
      end
      block_id = parent.id
    end
  end

  def summary(time=false)
    result = block_hash + " ("
    if size.present?
      result += "#{ (size / 1000.0 / 1000.0).round(2) } MB, "
    end
    if time && timestamp.present?
      result += "#{ Time.at(timestamp).utc.strftime("%H:%M:%S") } by "
    end
    return result + "#{ pool.present? ? pool : "unknown pool" })"
  end

  def self.create_with(block_info, node)
    # Set pool:
    pool = node.get_pool_for_block!(block_info["hash"], block_info)

    tx_count = block_info["nTx"].present? ? block_info["nTx"] :
               block_info["tx"].kind_of?(Array) ? block_info["tx"].count :
               nil

    Block.create(
     coin: node.coin.downcase.to_sym,
     block_hash: block_info["hash"],
     height: block_info["height"],
     mediantime: block_info["mediantime"],
     timestamp: block_info["time"],
     work: block_info["chainwork"],
     version: block_info["version"],
     tx_count:  tx_count,
     size: block_info["size"],
     first_seen_by: node,
     pool: pool
   )
 end

  def self.pool_from_coinbase_tx(tx)
    return nil if tx["vin"].nil? || tx["vin"].empty?
    coinbase = nil
    tx["vin"].each do |vin|
      coinbase = vin["coinbase"]
      break if coinbase.present?
    end
    throw "not a coinbase" if coinbase.nil?
    message = [coinbase].pack('H*')

    pools_ascii = {
      "--Nug--" => "shawnp0wers",
      "/$Mined by 7pool.com/" => "7pool",
      "/58coin.com/" => "58COIN",
      "/A-XBT/" => "A-XBT",
      "/AntPool/" => "Antpool",
      "/BATPOOL/" => "BATPOOL",
      "/BCMonster/" => "BCMonster",
      "/BTC.COM/" => "BTC.com",
      "/BTC.TOP/" => "BTC.TOP",
      "/BTCC/" => "BTCC Pool",
      "/BitClub Network/" => "BitClub Network",
      "/BitFury/" => "BitFury",
      "/Bitcoin-India/" => "Bitcoin India",
      "/Bitcoin-Russia.ru/" => "BitcoinRussia",
      "/Bitfury/" => "BitFury",
      "/Bixin/" => "Bixin",
      "/CANOE/" => "CANOE",
      "/ConnectBTC - Home for Miners/" => "ConnectBTC",
      "/DCExploration/" => "DCExploration",
      "/DPOOL.TOP/" => "DPOOL",
      "/HaoBTC/" => "Bixin",
      "/HotPool/" => "HotPool",
      "/Mined by HashBX.io/" => "HashBX",
      "/Nexious/" => "Nexious",
      "/NiceHashSolo" => "NiceHash Solo",
      "/RigPool.com/" => "RigPool",
      "/ViaBTC/" => "ViaBTC",
      "/WATERHOLE.IO/" => "Waterhole",
      "/agentD/" => "digitalBTC",
      "/bravo-mining/" => "Bravo Mining",
      "/ckpool.org/" => "CKPool",
      "/haominer/" => "Haominer",
      "/haozhuzhu/" => "HAOZHUZHU",
      "/mined by gbminers/" => "GBMiners",
      "/mined by poopbut/" => "MiningKings",
      "/mtred/" => "Mt Red",
      "/phash.cn/" => "PHash.IO",
      "/phash.io/" => "PHash.IO",
      "/pool34/" => "21 Inc.",
      "/poolin.com/" => "Poolin",
      "/slush/" => "SlushPool",
      "/solo.ckpool.org/" => "Solo CKPool",
      "50BTC" => "50BTC",
      "ASICMiner" => "ASICMiner",
      "BTC Guild" => "BTC Guild",
      "BTCChina Pool" => "BTCC Pool",
      "BTCChina.com" => "BTCC Pool",
      "BW Pool" => "BW.COM",
      "BitMinter" => "BitMinter",
      "Bitalo" => "Bitalo",
      "Bitsolo Pool" => "Bitsolo",
      "CoinLab" => "CoinLab",
      "EMC" => "EclipseMC",
      "Eligius" => "Eligius",
      "Give-Me-Coins" => "Give Me Coins",
      "HASHPOOL" => "HASHPOOL",
      "HHTT" => "HHTT",
      "Kano" => "KanoPool",
      "KnCMiner" => "KnCMiner",
      "MaxBTC" => "MaxBTC",
      "Mined By 175btc.com" => "175btc",
      "Mined by 1hash.com" => "1Hash",
      "Mined by AntPool" => "Antpool",
      "Mined by MultiCoin.co" => "MultiCoin.co",
      "Rawpool.com" => "Rawpool.com",
      "SigmaPool.com" => "SigmaPool.com",
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
      "ozco.in" => "OzCoin",
      "ozcoin" => "OzCoin",
      "pool.bitcoin.com" => "Bitcoin.com",
      "simplecoin" => "simplecoin.us",
      "st mining corp" => "ST Mining Corp",
      "triplemining" => "TripleMining",
      "viabtc.com deploy" => "ViaBTC",
      "xbtc.exx.com&bw.com" => "xbtc.exx.com&bw.com",
      "yourbtc.net" => "Yourbtc.net"
    }

    pools_utf8 = {
        "🐟" => "F2Pool"
    }

    pools_ascii.each do |match, name|
      return name if message.include?(match)
    end
    message_utf8 = message.force_encoding('UTF-8')
    pools_utf8.each do |match, name|
      return name if message_utf8.include?(match)
    end
    return nil
  end

  def self.check_inflation!
    Node.all.each do |node|
      next unless node.mirror_node? && node.core?
      puts "Check #{ node.coin } inflation for #{ node.name_with_version }..." unless Rails.env.test?
      throw "Node in Initial Blockchain Download" if node.ibd

      begin
        # Update mirror node tip and fetch most recent blocks if needed
        node.poll_mirror!
        best_mirror_block = Block.find_by(block_hash: node.mirror_client.getbestblockhash())
      rescue Bitcoiner::Client::JSONRPCError
        # Ignore failure
        puts "Unable to connect to mirror node #{ node.id } #{ node.name_with_version }, skipping inflation check."
        next
      end

      # Avoid expensive call if we already have this information for the most recent tip (of the mirror node):
      if best_mirror_block.present? && TxOutset.find_by(block: best_mirror_block, node: node).present?
        puts "Already checked #{ node.name_with_version } for current mirror tip" unless Rails.env.test?
        next
      end

      puts "Get the total UTXO balance at the mirror tip..." unless Rails.env.test?
      txoutsetinfo = node.mirror_client.gettxoutsetinfo
      
      # Make sure we have all blocks up to the mirror tip
      block = Block.find_by(block_hash: txoutsetinfo["bestblock"])
      if block.nil?
        puts "Latest block #{ txoutsetinfo["bestblock"] } at height #{ txoutsetinfo["height"] } missing in blocks database"
        next
      end

      tx_outset = TxOutset.create_with(txouts: txoutsetinfo["txouts"], total_amount: txoutsetinfo["total_amount"]).find_or_create_by(block: block, node: node)

      # Find previous block with txoutsetinfo
      max_inflation = 0
      comparison_block = block
      comparison_tx_outset = nil
      while true
        max_inflation += comparison_block.max_inflation / 100000000.0
        comparison_block = comparison_block.parent
        if comparison_block.nil?
          puts "Unable to check inflation due to missing intermediate block" unless Rails.env.test?
          break
        end
        comparison_tx_outset = TxOutset.find_by(node: node, block: comparison_block)
        break if comparison_tx_outset.present?
      end
      next if comparison_block.nil?

      # Check that inflation does not exceed the maximum permitted miner award per block
      inflation = tx_outset.total_amount - comparison_tx_outset.total_amount
      if inflation > max_inflation
        inflated_block = block.inflated_block || block.create_inflated_block(node: node,comparison_block: comparison_block, max_inflation: max_inflation, actual_inflation: inflation)
        if !inflated_block.notified_at
          User.all.each do |user|
            UserMailer.with(user: user, inflated_block: inflated_block).inflated_block_email.deliver
          end
          inflated_block.update notified_at: Time.now
          Subscription.blast("inflated-block-#{ inflated_block.id }",
                             "#{ inflated_block.actual_inflation -  inflated_block.max_inflation } BTC inflation",
                             "Unexpected #{ inflated_block.actual_inflation -  inflated_block.max_inflation } BTC extra inflation \
                             between block height #{ inflated_block.comparison_block.height } and #{ inflated_block.block.height } according to #{ node.name_with_version }.",
          )
        end
      end
      # TODO: Process each block and calculate inflation; compare with snapshot.
    end
  end

  def self.find_or_create_block_and_ancestors!(hash, node)
    # Not atomic and called very frequently, so sometimes it tries to insert
    # a block that was already inserted. In that case try again, so it updates
    # the existing block instead.
    begin
      block = Block.find_by(block_hash: hash)

      if block.nil?
        if node.client_type.to_sym == :libbitcoin
          block_info = node.client.getblockheader(hash)
        else
          block_info = node.client.getblock(hash)
        end

        block = Block.create_with(block_info, node)
      end

      block.find_ancestors!(node)
    rescue ActiveRecord::RecordNotUnique
      raise unless Rails.env.production?
      retry
    end
    return block
  end

end
