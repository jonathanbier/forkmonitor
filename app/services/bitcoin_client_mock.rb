class BitcoinClientMock
  def initialize(rpchost, rpcuser, rpcpassword)
    @height = 560176
    @reachable = true

    @block_hashes = {
      560176 => "0000000000000000000b1e380c92ea32288b0106ef3ed820db3b374194b15aab",
      560177 => "00000000000000000009eeed38d42da6428b0dcf596093a9d313bdd3d87c0eef"
    }
    @blocks = {}

    add_mock_block(560176, 1548498742, "000000000000000000000000000000000000000004dac4780fcbfd1e5710a2a5")
    add_mock_block(560177, 1548500251, "000000000000000000000000000000000000000004dac9d20e304bee0e69b31a")
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

  def getnetworkinfo
    raise Bitcoiner::Client::JSONRPCError if !@reachable
    {
      "version" => 170100,
      "subversion" => "/Satoshi:0.17.1/",
      "protocolversion" => 70015,
      "localservices" => "0000000000000409",
      "localrelay" => true,
      "timeoffset" => -1,
      "networkactive" => true,
      "connections" => 101,
      "networks" => [
        {
          "name" => "ipv4",
          "limited" => false,
          "reachable" => true
        },
        {
          "name" => "ipv6",
          "limited" => false,
          "reachable" => true
        }
      ],
      "warnings" => ""
    }
  end

  def getblockchaininfo
    {}
  end

  def getblockhash(height)
    @block_hashes[height]
  end

  def getbestblockhash
    @block_hashes[@height]
  end

  def getblock(hash)
    @blocks[hash]
  end

  private

  def add_mock_block(height, time, chainwork)
    @blocks[@block_hashes[height]] = {
      "height" => height,
      "time" => time,
      "chainwork" => chainwork,
      "hash" => @block_hashes[height]
    }
  end
end
