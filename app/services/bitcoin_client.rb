class BitcoinClient
  @@nodes = nil

  def initialize(rpchost, rpcuser, rpcpassword, name, pos)
    @client = Bitcoiner.new(rpcuser,rpcpassword,rpchost)
    @name = name
    @pos = pos
  end

  def pos
    @pos
  end

  def name
    @name
  end

  def client
    @client
  end

  # TODO: patch bitcoiner gem so we can do client.help (etc), get rid of
  #       these wrappers and avoid exposing @client.
  def help
    @client.request("help")
  end

  def getinfo
    @client.request("getinfo")
  end

  def getblockchaininfo
    @client.request("getblockchaininfo")
  end

  def getbestblockhash
    @client.request("getbestblockhash")
  end

  def getblock(hash)
    @client.request("getblock", hash)
  end

  # Update database with latest info from this node
  def poll!
    info = getinfo
    block_info = getblock(getbestblockhash)
    node = Node.create_with(name: @name, version: info["version"]).find_or_create_by(pos: @pos)
    block = Block.create_with(height: block_info["height"], timestamp: block_info["time"], work: block_info["chainwork"]).find_or_create_by(block_hash: block_info["hash"])
    node.update block: block
  end

  def self.nodes
    load_nodes! if @@nodes.nil?
    @@nodes
  end

  def self.load_nodes!
    @@nodes = []
    n = 0

    while n+=1
      break if ENV["NODE_#{ n }"].nil?
      credentials = ENV["NODE_#{ n }"].split("|")
      # TODO: sanity check credentials
      @@nodes << self.new(credentials[0], credentials[1], credentials[2], credentials[3], n)
    end

    return @@nodes
  end
end
