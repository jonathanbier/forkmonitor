class BitcoinClient
  def initialize(rpchost, rpcuser, rpcpassword)
    @client = Bitcoiner.new(rpcuser,rpcpassword,rpchost)
  end

# TODO: patch bitcoiner gem so we can do client.help (etc), get rid of
#       these wrappers and avoid exposing @client.
  def client
    @client
  end

  def help
    request("help")
  end

  def getnetworkinfo
    begin
      return request("getnetworkinfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getnetworkinfo failed for node #{@id}: " + e.message
      raise
    end
  end

  def getinfo
    begin
      return request("getinfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getinfo failed for node #{@id}: " + e.message
      raise
    end
  end

  def getblockchaininfo
    begin
      return request("getblockchaininfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getblockchaininfo failed for node #{@id}: " + e.message
      raise
    end
  end

  def getblockhash(height)
    begin
      return request("getblockhash", height)
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getblockhash #{ height } failed for node #{@id}: " + e.message
      raise
    end
  end

  def getbestblockhash
    begin
      return request("getbestblockhash")
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getbestblockhash failed for node #{@id}: " + e.message
      raise
    end
  end

  def getblock(hash, verbosity = 1)
    begin
      return request("getblock", hash)
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getblock(#{hash}) failed for node #{@id}: " + e.message
      raise
    end
  end

  def getblockheader(hash)
    begin
      return request("getblockheader", hash)
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getblockheader(#{hash}) failed for node #{@id}: " + e.message
      raise
    end
  end

  def getchaintips
    begin
      return request("getchaintips")
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getchaintips failed for node #{@id}: " + e.message
      raise
    end
  end

  def gettxoutsetinfo
    begin
      return request("gettxoutsetinfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "gettxoutsetinfo failed for node #{@id}: " + e.message
      raise
    end
  end

  private

  def request(*args)
    @client.request(*args)
  end
end
