class BitcoinClientMock
  def initialize(rpchost, rpcuser, rpcpassword)
    @height = 560176
    @reachable = true
    @ibd = false
    @peer_count = 100
    @version = 170100
    @coin = "BTC"

    @block_hashes = {
      560175 => "00000000000000000009eeed38d42da6428b0dcf596093a9d313bdd3d87c0eef",
      560176 => "0000000000000000000b1e380c92ea32288b0106ef3ed820db3b374194b15aab",
      560177 => "00000000000000000009eeed38d42da6428b0dcf596093a9d313bdd3d87c0eef",
      560178 => "00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9",
      560179 => "000000000000000000017b592e9ecd6ce8ab9b5a2f391e21ee2e80b022a7dafc"
    }
    @blocks = {}

    add_mock_block(560176, 1548498742, "000000000000000000000000000000000000000004dac4780fcbfd1e5710a2a5")
    add_mock_block(560177, 1548500251, "000000000000000000000000000000000000000004dac9d20e304bee0e69b31a")
    add_mock_block(560178, 1548502864, "000000000000000000000000000000000000000004dacf2c0c949abdc5c2c38f")
    add_mock_block(560179, 1548503410, "000000000000000000000000000000000000000004dad4860af8e98d7d1bd404")

  end

  def mock_coin(coin)
    @coin = coin
  end

  def mock_version(version)
    @version = version
  end

  def mock_set_height(height)
    @height = height
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

  def getnetworkinfo
    raise Bitcoiner::Client::JSONRPCError if !@reachable
    if @coin == "BTC"
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
        170100 => {
          "version" => 170100,
          "subversion" => "/Satoshi:0.17.1/",
          "protocolversion" => 70015,
          "localservices" => "0000000000000409",
          "localrelay" => true,
          "timeoffset" => -1,
          "networkactive" => true,
          "connections" => @peer_count,
          "warnings" => ""
        }
      }[@version]
    else
      {
        "version" => 180500,
        "subversion" => "/Bitcoin ABC:0.18.5(EB32.0)/",
        "protocolversion" => 70015,
        "localservices" => "0000000000000024",
        "localrelay"=> true,
        "timeoffset"=> 0,
        "networkactive"=> true,
        "connections"=> @peer_count,
        "relayfee" => 1.0e-05,
        "warnings" => "Warning: Unknown block versions being mined! It's possible unknown rules are in effect"}
    end
  end

  def getblockchaininfo
    {
      170100 => {
        "chain": "main",
        "blocks" => @height,
        "headers" => @height,
        "bestblockhash" => @block_hashes[@height],
        # "difficulty": 5883988430955.408,
        # "mediantime" => 1548515214,
        "verificationprogress" => 0.9999884832545263,
        "initialblockdownload" => @ibd,
        "chainwork" => @blocks[@block_hashes[@height]]["chainwork"],
        "size_on_disk" => 229120703086 + (@height - 560179) * 2000000,
        "pruned" => false,
        "softforks" => [],
        "bip9_softforks" => {},
        "warnings" => ""
      },
      100300 => {
        "chain" => "main",
        "blocks" => @height,
        "headers" => @height,
        "bestblockhash" => @block_hashes[@height],
        "verificationprogress" => @ibd ? 0.5 : 1.0,
        "chainwork" => @blocks[@block_hashes[@height]]["chainwork"]
      }
    }[@version]
  end

  def getblockhash(height)
    @block_hashes[height]
  end

  def getbestblockhash
    @block_hashes[@height]
  end

  def getblock(hash)
    raise Bitcoiner::Client::JSONRPCError unless @blocks[hash]

    return @blocks[hash].tap { |b| b.delete("mediantime") if @version <= 100300 }
  end

  private

  def add_mock_block(height, mediantime, chainwork)
    @blocks[@block_hashes[height]] = {
      "height" => height,
      "mediantime" => mediantime,
      "time" => mediantime,
      "chainwork" => chainwork,
      "hash" => @block_hashes[height],
      "previousblockhash" => @block_hashes[height - 1]
    }
  end
end