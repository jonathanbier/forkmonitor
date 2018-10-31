class BitcoinClient
  @@nodes = nil

  def initialize(rpchost, rpcuser, rpcpassword, name)
    @client = Bitcoiner.new(rpcuser,rpcpassword,rpchost)
    @name = name
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
      @@nodes << self.new(credentials[0], credentials[1], credentials[2], credentials[3])
    end

    return @@nodes
  end
end
