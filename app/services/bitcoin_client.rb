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
      # Try getnetworkinfo, fall back to getinfo for older nodes
      begin
        return request("getnetworkinfo")
      rescue Bitcoiner::Client::JSONRPCError => e
          if e.message.include?("404")
            return request("getinfo")
          else
            raise
          end
      end
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getnetworkinfo or getinfo failed for node #{@id}: " + e.message
      raise
    end
  end

  def getblockchaininfo
    request("getblockchaininfo")
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

  def getblock(hash)
    begin
      return request("getblock", hash)
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getblock(#{hash}) failed for node #{@id}: " + e.message
      raise
    end
  end

  private

  def request(*args)
    @client.request(*args)
  end
end
