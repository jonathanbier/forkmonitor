MINIMUM_BLOCK_HEIGHTS = {
  btc: Rails.env.test? ? 560176 : 500000, # Mid December 2017, around Lightning network launch
  tbtc: 1600000,
  bch: 581000,
  bsv:606000
}

class Block < ApplicationRecord
  has_many :children, class_name: 'Block', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Block', foreign_key: 'parent_id', optional: true
  has_many :invalid_blocks
  belongs_to :first_seen_by, class_name: 'Node', foreign_key: 'first_seen_by_id', optional: true
  has_many :tx_outsets
  has_one :inflated_block
  has_many :maybe_uncoop_transactions
  has_many :penalty_transactions
  has_many :sweep_transactions
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

  def find_ancestors!(node, use_mirror, until_height = nil)
    block_id = self.id
    block_ids = []
    client = use_mirror ? node.mirror_client : node.client
    loop do
      block_ids.append(block_id)
      block = Block.find(block_id)
      # Prevent new instances from going too far back:
      break if block.height == MINIMUM_BLOCK_HEIGHTS[block.coin.to_sym]
      break if until_height && block.height == until_height
      parent = block.parent
      if parent.nil?
        if node.client_type.to_sym == :libbitcoin
          block_info = client.getblockheader(block.block_hash)
        else
          block_info = client.getblock(block.block_hash)
        end
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
          block_info = client.getblock(block_info["previousblockhash"])
        end

        parent = Block.create_with(block_info, use_mirror, node)
        block.update parent: parent
      end
      block_id = parent.id
    end
    # Go back up to the tip to mark blocks as connected
    return if until_height && !Block.find(block_id).connected
    Block.where("id in (?)", block_ids).update connected: true
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

  def self.create_with(block_info, use_mirror, node)
    # Set pool:
    pool = node.get_pool_for_block!(block_info["hash"], use_mirror, block_info)

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

  def self.find_or_create_block_and_ancestors!(hash, node, use_mirror)
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
          block_info = client.getblock(hash)
        end
        block = Block.create_with(block_info, use_mirror, node)
      end

      block.find_ancestors!(node, use_mirror)
    rescue ActiveRecord::RecordNotUnique
      raise unless Rails.env.production?
      retry
    end
    return block
  end

end
