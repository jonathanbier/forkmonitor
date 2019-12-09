class BitcoinClientMock
  class Error < StandardError
  end

  def initialize(node_id, name_with_version, client_type, rpchost, rpcport, rpcuser, rpcpassword)
    @height = 560176
    @block_hash = "0000000000000000000b1e380c92ea32288b0106ef3ed820db3b374194b15aab"
    @best_height = 560176
    @reachable = true
    @ibd = false
    @peer_count = 100
    @version = 170100
    @coin = "BTC"
    @client_type = :core
    @chaintips = []
    @extra_inflation = 0
    @networkactive = true
    @node_id = node_id
    @name_with_version = name_with_version

    @block_hashes = {
      975 => "00000000d67ac3dab052ac69301316b73678703e719ce3757e31e5b92444e64c",
      976 => "00000000ed7ccf7b89a2f3fc7eac955412ba92f29f1a3f7fa336e05be728724e",
      560175 => "00000000000000000017e4576f60568af86b39ddd76dc4b182ea0bd645f5c499",
      560176 => "0000000000000000000b1e380c92ea32288b0106ef3ed820db3b374194b15aab",
      560177 => "00000000000000000009eeed38d42da6428b0dcf596093a9d313bdd3d87c0eef",
      560178 => "00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9",
      560179 => "000000000000000000017b592e9ecd6ce8ab9b5a2f391e21ee2e80b022a7dafc",
      560180 => "0000000000000000002d802cf5fdbbfa94926be7f03b40be75eb6c3c13cbc8e4",
      560181 => "0000000000000000002641ea2457674fea1b2fc5fcfe6fde416dca2a0e13aec2",
      560182 =>   "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377"
    }
    @fork_block_hashes = {
      560177 => "0000000000000000000000000000000000000000000000000000000000560177",
      560178 => "0000000000000000000000000000000000000000000000000000000000560178"
    }
    @fork_block_info = {
        "0000000000000000000000000000000000000000000000000000000000560177" => {
            chainwork: "000000000000000000000000000000000000000004dac9d20e304bee0e69b31a",
            previousblockhash: nil # connected to main chain
        },
        "0000000000000000000000000000000000000000000000000000000000560178" => {
            chainwork: "000000000000000000000000000000000000000004dacf2c0c949abdc5c2c38f",
            previousblockhash: "0000000000000000000000000000000000000000000000000000000000560177"
        }
    }
    @blocks = {}
    @block_headers = {}
    @raw_blocks = {
      # 560177: actually block 603351 (empty)
      "0000000000000000000b1e380c92ea32288b0106ef3ed820db3b374194b15aab" => "000040204cd87f8c0d91fbdf42f73748ea8324d191cc0a4f606806000000000000000000b45e927dc0db75bff9b0ddf83ac0d8166c79ae7622599e9ad6353f76522639c72dc5c95dd12016176defd08101010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff1903d734090d6506046c666bf5da0000319d102f736c7573682f0000000002807c814a000000001976a9147c154ed1dc59609e3d26abb2df2ea3d587cd8c4188ac0000000000000000266a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf90120000000000000000000000000000000000000000000000000000000000000000000000000",
      # 560177: actually block 603351 (empty)
      "00000000000000000009eeed38d42da6428b0dcf596093a9d313bdd3d87c0eef" => "000040204cd87f8c0d91fbdf42f73748ea8324d191cc0a4f606806000000000000000000b45e927dc0db75bff9b0ddf83ac0d8166c79ae7622599e9ad6353f76522639c72dc5c95dd12016176defd08101010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff1903d734090d6506046c666bf5da0000319d102f736c7573682f0000000002807c814a000000001976a9147c154ed1dc59609e3d26abb2df2ea3d587cd8c4188ac0000000000000000266a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf90120000000000000000000000000000000000000000000000000000000000000000000000000"
    }
    @transactions = {}

    mock_add_block(976, 1232327230, "000000000000000000000000000000000000000000000000000003d103d103d1", nil, nil)
    mock_add_block(560176, 1548498742, "000000000000000000000000000000000000000004dac4780fcbfd1e5710a2a5", nil, nil)
    mock_add_block(560177, 1548500251, "000000000000000000000000000000000000000004dac9d20e304bee0e69b31a", nil, nil, 536870914) # 0x20000002 bit 1 (SegWit)
    mock_add_block(560178, 1548502864, "000000000000000000000000000000000000000004dacf2c0c949abdc5c2c38f", nil, nil, 536870930) # 0x20000012 bit 1 & 4
    mock_add_block(560179, 1548503410, "000000000000000000000000000000000000000004dad4860af8e98d7d1bd404", nil, nil)
    mock_add_block(560180, 1548498447, "000000000000000000000000000000000000000004dad9e0095d385d3474e479", nil, nil)
    mock_add_block(560181, 1548498742, "000000000000000000000000000000000000000004dadf3a07c1872cebcdf4ee", nil, nil)
    mock_add_block(560182, 1548500251, "000000000000000000000000000000000000000004dae4940625d5fca3270563", nil, nil)

    mock_add_transaction("0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377", "74e243e5425edfce9486e26aa6449e56c68351210e8edc1fe81ddcdc8d478085", "010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff5303368c081a4d696e656420627920416e74506f6f6c633e007902205c4c4eadfabe6d6dd1950c951397395896a26405b01c17c50070f4a287b029b377eae4148bc9133f04000000000000005201000079650000ffffffff03478b704b000000001976a914edf10a7fac6b32e24daa5305c723f3de58db1bc888ac0000000000000000266a24aa21a9ed8d4ee584d2bd2483c525df85654a2fcfa9125638dd6fe56405a0590b3da0347800000000000000002952534b424c4f434b3ac6695c75ffa1f93f9237c6997abd16c988a3b442545478f81fd49d9af1b2ce9a0120000000000000000000000000000000000000000000000000000000000000000000000000")
  end

  def mock_coin(coin)
    @coin = coin
  end

  def mock_version(version)
    @version = version
  end

  def mock_client_type(type)
    @client_type = type
  end

  def mock_set_height(height)
    # If a mock fork exists at previous height, add it as a valid-fork
    if @blocks[@fork_block_hashes[height - 1]].present?
      @chaintips.push({
          "height" => height - 1,
          "hash" => @fork_block_hashes[height - 1],
          "branchlen" => 1,
          "status" => "valid-fork"
      })
    end
    @chaintips.delete_if { |t| t["status"] == "active" }
    @height = height
    @block_hash = @block_hashes[@height]
    @best_height = height
    @chaintips.push({
        "height" => height,
        "hash" => @block_hash,
        "branchlen" => 0,
        "status" => "active"
    })
  end

  def mock_unreachable
    @reachable = false
  end

  def mock_reachable
    @reachable = true
  end

  def mock_ibd(status)
    @ibd = status
  end

  def mock_peer_count(peer_count)
    @peer_count = peer_count
  end

  def mock_chaintips(tips)
    @chaintips = tips
  end

  def mock_set_extra_inflation(amount)
    @extra_inflation = amount
  end

  def getblockcount
    return @height
  end

  def getblockheight
    if @client_type == :libbitcoin
      return @height
    else
      raise Error, "Only used by libbitcoin"
    end
  end

  def getinfo
    raise Error if !@reachable
    if @coin == "BTC"
      if @client_type == :core
        res = {
          80600 => {
            "version" => 80600,
            "protocolversion" => 70001,
            "blocks" => @height,
            # "difficulty" => 5883988430955.408,
            "warnings" => "",
            "errors" => "URGENT: Alert key compromised, upgrade required",
            "connections" => 8
          }
        }
      elsif @client_type == :btcd
        res = {
          120000 => {
            "version" => 120000,
            "protocolversion" => 70002,
            "blocks" => @height,
            "timeoffset"=>0,
            "connections"=>8,
            "proxy"=>"",
            # "difficulty"=>7934713219630.606,
            "testnet"=>false,
            "relayfee"=>1.0e-05,
            "errors"=>""
          }
        }
      end
    end

    throw "No getinfo mock for #{ @client_type }" unless res.present?
    res[@version]
  end

  def getnetworkinfo
    raise Error if !@reachable
    if @coin == "BTC"
      if @client_type == :core
        raise Error if @version < 100000
        {
          100300 => {
            "version" => 100300,
            "subversion" => "/Satoshi:0.10.3/",
            "protocolversion" => 70002,
            "localservices" => "0000000000000001",
            "timeoffset" => 0,
            "connections" => @peer_count,
            "relayfee"=>5.0e-05,
          },
          130000 =>
          {
            "version" => 130000,
            "subversion" => "/Satoshi:0.13.0/",
            "protocolversion" => 70014,
            "localservices" => "0000000000000005",
            "localrelay" => true,
            "timeoffset" => 0,
            "connections" => 8,
            "networks" => [
            ],
            "relayfee" => 0.00001000,
            "localaddresses" => [],
            "warnings" => ""
          },
          160300 => {
            "version" => 160300,
            "subversion" => "/Satoshi:0.16.3/",
            "protocolversion" => 70015,
            "localservices" => "0000000000000409",
            "localrelay" => true,
            "timeoffset" => -1,
            "networkactive" => @network_active,
            "connections" => @peer_count,
            "warnings" => ""
          },
          170100 => {
            "version" => 170100,
            "subversion" => "/Satoshi:0.17.1/",
            "protocolversion" => 70015,
            "localservices" => "0000000000000409",
            "localrelay" => true,
            "timeoffset" => -1,
            "networkactive" => @network_active,
            "connections" => @peer_count,
            "warnings" => ""
          },
        }[@version]
      elsif @client_type == :bcoin
        {
          "v1.0.2" => {
            "version" => "v1.0.2",
            "subversion" => "/bcoin:v1.0.2/",
            "protocolversion" => 70015,
            "localservices" => "00000009",
            "localrelay" => true,
            "timeoffset" => 0,
            "networkactive" => @network_active,
            "connections" => @peer_count,
            "warnings" => ""
          },
        }[@version]
      elsif @client_type == :btcd
        raise Error
      else
        throw "No getnetworkinfo mock for #{ @client_type }"
      end
    elsif @coin == "BCH"
      {
        180500 => {
          "version" => 180500,
          "subversion" => "/Bitcoin ABC:0.18.5(EB32.0)/",
          "protocolversion" => 70015,
          "localservices" => "0000000000000024",
          "localrelay"=> true,
          "timeoffset"=> 0,
          "networkactive"=> @network_active,
          "connections"=> @peer_count,
          "relayfee" => 1.0e-05,
          "warnings" => "Warning: Unknown block versions being mined! It's possible unknown rules are in effect"
        }
      }[@version]
    else # SV: using the same mock data as ABC for now
      {
        180500 => {
          "version" => 180500,
          "subversion" => "/Bitcoin ABC:0.18.5(EB32.0)/",
          "protocolversion" => 70015,
          "localservices" => "0000000000000024",
          "localrelay"=> true,
          "timeoffset"=> 0,
          "networkactive"=> @network_active,
          "connections"=> @peer_count,
          "relayfee" => 1.0e-05,
          "warnings" => "Warning: Unknown block versions being mined! It's possible unknown rules are in effect"
        }
      }[@version]
    end
  end

  def setnetworkactive(status)
    @network_active = status
  end

  def getblockchaininfo
    raise Error if !@reachable
    if @coin == "BTC"
      if @client_type == :core
        raise Error if @version < 100000
        res = {
          170100 => {
            "chain" => "main",
            "blocks" => @height,
            "headers" => @height,
            "bestblockhash" => @block_hash,
            # "difficulty" => 5883988430955.408,
            "mediantime" => 1548515214,
            "verificationprogress" => @ibd ? 1.753483709675226e-06 : 1.0,
            "initialblockdownload" => @ibd,
            "chainwork" => @blocks[@block_hashes[@height]]["chainwork"],
            "size_on_disk" => 229120703086 + (@height - 560179) * 2000000,
            "pruned" => false,
            "softforks" => [],
            "bip9_softforks" => {},
            "warnings" => ""
          },
          160300 => {
            "chain" => "main",
            "blocks" => @height,
            "headers" => @height,
            "bestblockhash" => @block_hash,
            # "difficulty" => 5883988430955.408,
            "mediantime" => 1548515214,
            "verificationprogress" => @ibd ? 1.753483709675226e-06 : 1.0,
            "initialblockdownload" => @ibd,
            "chainwork" => @blocks[@block_hashes[@height]]["chainwork"],
            "size_on_disk" => 229120703086 + (@height - 560179) * 2000000,
            "pruned" => false,
            "softforks" => [],
            "bip9_softforks" => {},
            "warnings" => ""
          },
          130000 => {
            "chain" => "main",
            "blocks" => @height,
            "headers" => @height,
            "bestblockhash" => @block_hash,
            # "difficulty" => 1,
            "mediantime" => 1232327230,
            "verificationprogress" => @ibd ? 1.753483709675226e-06 : 1.0,
            "chainwork" => @blocks[@block_hashes[@height]]["chainwork"],
            "pruned" => false,
            "softforks" => [],
            "bip9_softforks" => {
            }
          },
          100300 => {
            "chain" => "main",
            "blocks" => @height,
            "headers" => @height,
            "bestblockhash" => @block_hash,
            "verificationprogress" => @ibd ? 0.5 : 1.0,
            "chainwork" => @blocks[@block_hashes[@height]]["chainwork"]
          },
        }
      elsif @client_type == :btcd
        res = {
          120000 => {
            "chain" => "main",
            "blocks" => @height,
            "headers" => @height,
            "bestblockhash" => @block_hashes[@height],
            # "difficulty" => 1,
            "mediantime" => 1232327230,
            "verificationprogress" => @ibd ? 1.753483709675226e-06 : 1.0,
            "chainwork" => @blocks[@block_hashes[@height]]["chainwork"],
            "pruned" => false,
            "softforks" => [],
            "bip9_softforks" => {
            }
          },
        }
      elsif @client_type == :bcoin
        res = {
          "v1.0.2" => {
            "chain" => "main",
            "blocks" => @height,
            "headers" => @height,
            "bestblockhash" => @block_hashes[@height],
            # "difficulty" => 7934713219630.606,
            "mediantime" => 1562238877,
            "verificationprogress" => @ibd ? 1.753483709675226e-06 : 1.0,
            "chainwork" => @blocks[@block_hashes[@height]]["chainwork"],
            "pruned" => true,
            "softforks" => [],
            "bip9_softforks" => {},
            "pruneheight" => @height - 1000
          }
        }
      end
    elsif @coin == "TBTC" # tesnet
      if @client_type == :core
        raise Error if @version < 100000
        res = {
          170100 => {
            "chain" => "test",
            "blocks" => @height,
            "headers" => @height,
            "bestblockhash" => @block_hash,
            "mediantime" => 1548515214,
            "verificationprogress" => @ibd ? 1.753483709675226e-06 : 1.0,
            "initialblockdownload" => @ibd,
            "chainwork" => @blocks[@block_hashes[@height]]["chainwork"],
            "size_on_disk" => 229120703086 + (@height - 560179) * 2000000,
            "pruned" => false,
            "softforks" => [],
            "bip9_softforks" => {},
            "warnings" => ""
          }
        }
      end
    elsif @coin == "BCH"
      res = {
        180500 => { # Copied from BTC
          "chain" => "main",
          "blocks" => @height,
          "headers" => @height,
          "bestblockhash" => @block_hashes[@height],
          # "difficulty" => 5883988430955.408,
          "mediantime" => 1548515214,
          "verificationprogress" => @ibd ? 1.753483709675226e-06 : 1.0,
          "initialblockdownload" => @ibd,
          "chainwork" => @blocks[@block_hashes[@height]]["chainwork"],
          "size_on_disk" => 229120703086 + (@height - 560179) * 2000000,
          "pruned" => false,
          "softforks" => [],
          "bip9_softforks" => {},
          "warnings" => ""
        }
      }
    else # BSV
      res = {
        180500 => { # Copied from BTC
          "chain" => "main",
          "blocks" => @height,
          "headers" => @height,
          "bestblockhash" => @block_hashes[@height],
          # "difficulty" => 5883988430955.408,
          "mediantime" => 1548515214,
          "verificationprogress" => @ibd ? 1.753483709675226e-06 : 1.0,
          "initialblockdownload" => @ibd,
          "chainwork" => @blocks[@block_hashes[@height]]["chainwork"],
          "size_on_disk" => 229120703086 + (@height - 560179) * 2000000,
          "pruned" => false,
          "softforks" => [],
          "bip9_softforks" => {},
          "warnings" => ""
        }
      }
    end
    throw "No getblockchaininfo mock for #{ @client_type }" unless res.present?
    res[@version]
  end

  def getblockhash(height) # does not take forks into account
    @block_hashes[height]
  end

  def getbestblockhash
    @block_hash
  end

  def getblock(hash, verbosity = 1)

    if verbosity == 0
      raise Error unless @raw_blocks[hash]
      return @raw_blocks[hash]
    elsif verbosity == 1
      raise Error unless @blocks[hash]
      return @blocks[hash].tap { |b| b.delete("mediantime") if @version <= 100300 }
    else
      raise Error, "Unexpected verbosity=#{ verbosity }"
    end
  end

  def getblockheader(hash_or_height) # height argument does not take fork into account
    if @client_type == :libbitcoin
      raise Error, "Must provide height or hash" unless hash_or_height.present?
      if hash_or_height.is_a?(Numeric)
        hash = @block_hashes[hash_or_height]
      else
        hash = hash_or_height
      end
      raise Error, hash unless @blocks[hash]
      return @block_headers[hash].tap { |b| b.delete("mediantime") && b.delete("time") && b.delete("chainwork") }
    else
      throw "Must provide hash" if hash_or_height.is_a?(Numeric)
      hash = hash_or_height
      # Added in Bitcoin Core v0.12
      raise Error, hash if @client_type == :core && @version < 120000
      raise Error, hash unless @blocks[hash]
      return @block_headers[hash].tap { |b| b.delete("size"); b.delete("mediantime") if @version <= 100300 }
    end
  end

  def getchaintips
    @chaintips
  end

  def gettxoutsetinfo # does not take forks into account
    if @height == 560176
      return {
        "height" => @height, # Actually 572023
        "bestblock" => @block_hashes[@height],
        "transactions" => 29221340,
        "txouts" => 53336961,
        "bogosize" => 4018808071,
        "hash_serialized_2" => "9bd2d3a6d6aa32e68f3c48286986a1c8771180f2c46bb316bb0073b194835d6b",
        "disk_size" => 3202897585,
        "total_amount" => 17650117.32457854
      }
    elsif @height == 560177 # Actually 572023
      return {
        "height" => @height, # Actually 572023
        "bestblock" => @block_hashes[@height],
        "transactions" => 29221340,
        "txouts" => 53336961,
        "bogosize" => 4018808071,
        "hash_serialized_2" => "9bd2d3a6d6aa32e68f3c48286986a1c8771180f2c46bb316bb0073b194835d6b",
        "disk_size" => 3202897585,
        "total_amount" => 17650117.32457854 + 12.5
      }
    elsif @height == 560178
      return {
        "height" => @height, # Actually 572025,
        "bestblock" => @block_hashes[@height],
        "transactions" => 29222816,
        "txouts" => 53340690,
        "bogosize" => 4019083859,
        "hash_serialized_2" => "f970cc0aabb3adff4e18a75460ef58c91eb8a181ec97e0d3d8acb71f55402c0a",
        "disk_size" => 3147778574,
        "total_amount" => 17650142.32457854 + @extra_inflation * 2
      }
    elsif @height == 560179
      return {
        "height" => @height, # Actually 572025,
        "bestblock" => @block_hashes[@height],
        "transactions" => 29222816,
        "txouts" => 53340690,
        "bogosize" => 4019083859,
        "hash_serialized_2" => "f970cc0aabb3adff4e18a75460ef58c91eb8a181ec97e0d3d8acb71f55402c0a",
        "disk_size" => 3147778574,
        "total_amount" => 17650142.32457854 + 12.5 + @extra_inflation * 3
      }
    end
    throw "No mock txoutset for height #{ @height }"
  end

  def getrawtransaction(tx_hash, verbose = false, block_hash = nil)
    raw_tx = @transactions[tx_hash]
    if !verbose
      raise Error if raw_tx.nil?
      return raw_tx
    else
      return {}
    end
  end

  def invalidateblock(block_hash)
    header = @block_headers[block_hash]
    throw "Block #{ block_hash } not found" unless header.present?
    # Mark the current tip as invalid:
    throw "No active chaintip" unless @chaintips.find { |t| t["status"] == "active" }
    @chaintips.map! { |t|
      if t["status"] == "active"
        t["status"] = "invalid"
      end
      t
    }
    # Determine the new active chaintip. This is 1 below the previously active
    # tip, unless:
    # 1. there is a valid fork to jump to at the original height
    # 2. there is a valid fork at height - 1 AND it was seen earlier
    fork = @chaintips.find { |t| t["status"] == "valid-fork" && t["height"] == header["height"]}
    if fork.present?
      @chaintips.map! { |t|
        if t["status"] == "valid-fork"
          t["status"] = "active"
          t["branchlen"] = 0
        end
        t
      }
      @block_hash = fork["hash"]
    else
      mock_set_height(header["height"] - 1)
      fork = @chaintips.find { |t| t["status"] == "valid-fork" && t["height"] == header["height"] - 1}
      if fork.present?
        # If valid-fork is older (real world nodes check block was seen earlier, not the mediantime),
        # switch to it. Otherwise stay on the main chain.
        if @block_headers[fork["hash"]]["mediantime"] < @block_headers[@block_hashes[header["height"] - 1]]["mediantime"]
          @chaintips.map! { |t|
            if t["status"] == "active"
              t["status"] = "valid-fork"
              t["branchlen"] = 1
            elsif t["status"] == "valid-fork"
              t["status"] = "active"
              t["branchlen"] = 0
            end
            t
          }
          @block_hash = fork["hash"]
        end
      end
    end
  end

  def reconsiderblock(block_hash)
    header = @block_headers[block_hash]
    throw "Block #{ block_hash } not found" unless header.present?
    # Mark the invalid chaintip (if any) as active
    activated_block = nil
    @chaintips.map! { |t|
      if t["status"] == "invalid" # TODO: disambiguate if there are forks
        t["status"] = "active"
        @height = t["height"]
        @best_height = @height
        activated_block = t["hash"]
      end
      t
    }
    if activated_block.present?
      # Remove previous active tip
      @chaintips.delete_if { |t| t["status"] == "active" && t["hash"] != activated_block}
    end
  end

  def mock_add_block(height, mediantime, chainwork, block_hash=nil, previousblockhash=nil, version=536870912) # versionHex 0x20000000
    block_hash ||= @block_hashes[height]
    previousblockhash ||= @block_hashes[height - 1]
    version_bits ||= []

    header = {
      "height" => height,
      "time" => mediantime,
      "mediantime" => mediantime,
      "chainwork" => chainwork,
      "hash" => block_hash,
      "previousblockhash" => previousblockhash,
      "version" => version # default 0x20000000
    }
    @block_headers[block_hash] = header
    @blocks[block_hash] = header
    @blocks[block_hash]["tx"] = []
    @blocks[block_hash]["nTx"] = 0
    @blocks[block_hash]["size"] = 100
  end

  def mock_add_fork_block(height, relative_time = 1)
      block_hash = @fork_block_hashes[height]
      mock_add_block(height, @block_headers[@block_hashes[height]]["mediantime"] + relative_time, @fork_block_info[block_hash][:chainwork], block_hash, @fork_block_info[block_hash][:previousblockhash])
  end

  def mock_add_transaction(block_hash, tx_hash, raw_transaction)
    @blocks[block_hash]["tx"] << tx_hash
    @blocks[block_hash]["nTx"] = @blocks[block_hash]["nTx"] + 1
    @blocks[block_hash]["size"] = @blocks[block_hash]["size"] + 150
    @transactions[tx_hash] = raw_transaction
  end
end
