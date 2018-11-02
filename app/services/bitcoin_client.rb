class BitcoinClient
  @@nodes = nil

  def initialize(coin, rpchost, rpcuser, rpcpassword, name, pos)
    @client = Bitcoiner.new(rpcuser,rpcpassword,rpchost)
    @coin = coin
    @name = name
    @pos = pos
  end

  def coin
    @coin
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
      puts "getnetworkinfo or getinfo failed for node #{@pos}: " + e.message
      raise
    end
  end

  def getblockchaininfo
    request("getblockchaininfo")
  end

  def getbestblockhash
    begin
      return request("getbestblockhash")
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getbestblockhash failed for node #{@pos}: " + e.message
      raise
    end
  end

  def getblock(hash)
    begin
      return request("getblock", hash)
    rescue Bitcoiner::Client::JSONRPCError => e
      puts "getblock(#{hash}) failed for node #{@pos}: " + e.message
      raise
    end
  end

  # Update database with latest info from this node
  def poll!
    begin
      info = getnetworkinfo
      block_info = getblock(getbestblockhash)
    rescue Bitcoiner::Client::JSONRPCError
      node = Node.create_with(name: @name, version: info.present? && info["version"]).find_or_create_by(pos: @pos)
      node.update unreachable_since: node.unreachable_since || DateTime.now
      return
    end

    node = Node.create_with(coin: @coin, name: @name, version: info["version"]).find_or_create_by(pos: @pos)
    block = Block.create_with(height: block_info["height"], timestamp: block_info["time"], work: block_info["chainwork"]).find_or_create_by(block_hash: block_info["hash"])
    node.update block: block, unreachable_since: nil
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
      @@nodes << self.new(credentials[0], credentials[1], credentials[2], credentials[3], credentials[4], n)
    end

    return @@nodes
  end

  def self.poll!
    self.nodes.each do |node|
      puts "Polling #{ node.coin } node #{node.pos} (#{node.name})..."
      node.poll!
    end
  end

  def self.poll_repeat!
    # Trap ^C
    Signal.trap("INT") {
      puts "\nShutting down gracefully..."
      exit
    }

    # Trap `Kill `
    Signal.trap("TERM") {
      puts "\nShutting down gracefully..."
      exit
    }

    while true
      sleep 1

      self.nodes.each do |node|
        puts "Polling #{ node.coin } node #{node.pos} (#{node.name})..."
        node.poll!
      end
    end
  end

  private

  def request(*args)
    @client.request(*args)
  end
end
