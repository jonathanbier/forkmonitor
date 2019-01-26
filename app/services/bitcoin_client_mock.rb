class BitcoinClientMock
  def initialize(rpchost, rpcuser, rpcpassword)
    @height = 560176
    @reachable = true

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
    return @blocks[hash] if @blocks[hash]
    raise Bitcoiner::Client::JSONRPCError
  end

  private

  def add_mock_block(height, time, chainwork)
    @blocks[@block_hashes[height]] = {
      "height" => height,
      "time" => time,
      "chainwork" => chainwork,
      "hash" => @block_hashes[height],
      "previousblockhash" => @block_hashes[height - 1]
    }
  end
end
