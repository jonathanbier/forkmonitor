require '0mq'
require 'digest'

class BitcoinClient
  class Error < StandardError; end
  class ConnectionError < Error; end
  class PartialFileError < Error; end
  class BlockPrunedError < Error; end
  class BlockNotFoundError < Error; end
  class MethodNotFoundError < Error; end
  class TimeOutError < Error; end
  class PeerNotConnected < Error; end
  class NodeInitializingError < Error; end

  def initialize(node_id, name_with_version, coin, client_type, client_version, rpchost, rpcport, rpcuser, rpcpassword)
    @coin = coin
    @client_type = client_type
    @client_version = client_version
    if @client_type == :libbitcoin
      @socket = ZMQ::Socket.new ZMQ::REQ
      @socket_uri = "tcp://#{ rpchost }:#{ rpcport }"
      zmq_connect
    else
      @client = Bitcoiner.new(rpcuser,rpcpassword, "#{ rpchost }:#{ rpcport }")
    end
    @node_id = node_id
    @name_with_version = name_with_version
  end

  def zmq_connect
    @socket.connect @socket_uri
    @zmq_connected = true
  end

  def zmq_disconnect
    @socket.disconnect @socket_uri
    @zmq_connected = false
  end

# TODO: patch bitcoiner gem so we can do client.help (etc), get rid of
#       these wrappers and avoid exposing @client.
  def client
    @client
  end

  def recv_array_with_timeout(socket, timeout, command)
    begin
      Timeout::timeout(timeout) {
        # Maximum 5 seconds of patience.
        # The use of Thread.interrupt is considered unsafe, but at least we're not
        # locking a database.
        return socket.recv_array
      }
    rescue Timeout::Error => e
        puts "Timeout: #{ command }"
        zmq_disconnect
        return nil
    end
  end

  def help(command=nil)
    if command.nil?
      request("help")
    else
      request(command)
    end
  end

  def disconnectnode(address, peer_id)
    begin
      return request("disconnectnode", address, peer_id)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise PeerNotConnected if e.message.include?("Node not found in connected nodes")
      raise Error, "disconnectnode(#{address},#{peer_id}) failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getnetworkinfo
    begin
      return request("getnetworkinfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getnetworkinfo failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getpeerinfo
    begin
      return request("getpeerinfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getpeerinfo failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockcount
    begin
      return request("getblockcount")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getblockcount failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockheight
    raise Error, "Not implemented" unless @client_type == :libbitcoin
    command = 'blockchain.fetch_last_height'
    zmq_connect unless @zmq_connected
    @socket.send_array [command.b, [1].pack("I"), ''.b]

    res = recv_array_with_timeout(@socket, 5, command)
    return nil if res.nil?

    error_code = res[2][0..3].unpack("L<")[0]
    throw "#{ command } failed #{ @coin } with error code: #{ error_code }" if error_code > 0
    return res[2][4..-1].unpack("L<")[0]
  end

  def getinfo
    begin
      # TODO: patch https://github.com/NARKOZ/bitcoiner (which uses https://github.com/typhoeus/typhoeus)
      # to check for timeout.
      Timeout::timeout(10) {
        return request("getinfo")
      }
    rescue Timeout::Error
      raise TimeOutError
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getinfo failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockchaininfo
    begin
      Timeout::timeout(10) {
        return request("getblockchaininfo")
      }
    rescue Timeout::Error
      raise TimeOutError
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getblockchaininfo failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockhash(height)
    begin
      return request("getblockhash", height)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getblockhash #{ height } failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getbestblockhash
    begin
      return request("getbestblockhash")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getbestblockhash failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblock(hash, verbosity)
    begin
      return request("getblock", hash, verbosity)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise PartialFileError if e.message.include?("partial_file")
      raise BlockPrunedError if e.message.include?("pruned data")
      raise BlockNotFoundError if e.message.include?("Block not found")
      raise Error, "getblock(#{hash},#{verbosity}) failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockfrompeer(hash, peer_id)
    begin
      return request("getblockfrompeer", hash, peer_id)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getblockfrompeer(#{hash},#{peer_id}) failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockheader(hash_or_height, verbose = true)
    throw "Must provide a hash or height" if hash_or_height.nil?
    if @client_type != :libbitcoin
      hash = hash_or_height
      begin
        return request("getblockheader", hash, verbose)
      rescue Bitcoiner::Client::JSONRPCError => e
        raise BlockNotFoundError if e.message.include?("Block not found")
        raise Error, "getblockheader(#{hash},#{verbose}) failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
      end
    else
      command = 'blockchain.fetch_block_header'
      zmq_connect unless @zmq_connected
      @socket.send_array [command.b, [1].pack("I"), hash_or_height.is_a?(Numeric) ? [hash_or_height].pack("I") : [hash_or_height.reverse].pack("h*")]
      res = recv_array_with_timeout(@socket, 5, command)
      return nil if res.nil?
      error_code = res[2][0..3].unpack("L<")[0]
      throw "#{ command } failed with error code: #{ error_code }" if error_code > 0
      block_header = res[2][4..-1]
      block_version = block_header[0..3].unpack("h*")[0]
      previousblockhash = block_header[4..(4 + 32 - 1)].unpack("h*")[0].reverse()
      block_hash = Digest::SHA2.digest(Digest::SHA2.digest(block_header)).unpack("h*")[0].reverse()

      if hash_or_height.is_a?(Numeric)
        height = hash_or_height
      else
        command = 'blockchain.fetch_block_height'
        zmq_connect unless @zmq_connected
        @socket.send_array [command.b, [1].pack("I"), [block_hash.reverse].pack("h*")]
        res = recv_array_with_timeout(@socket, 5, command)
        return nil if res.nil?
        error_code = res[2][0..3].unpack("L<")[0]
        throw "#{ command } failed with error code: #{ error_code }" if error_code > 0
        height = res[2][4..-1].unpack("L<")[0]
      end

      return {
        "height" => height,
        "version" => block_version,
        # TODO: get time
        "hash" => block_hash,
        "previousblockhash" => previousblockhash
      }
    end
  end

  def getchaintips
    begin
      return request("getchaintips")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getchaintips failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getmempoolinfo
    begin
      return request("getmempoolinfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getmempoolinfo failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def gettxoutsetinfo
    begin
      return request("gettxoutsetinfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "gettxoutsetinfo failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getrawtransaction(hash, verbose = false, block_hash = nil)
    begin
      if block_hash.present?
        return request("getrawtransaction", hash, verbose, block_hash)
      else
        return request("getrawtransaction", hash, verbose)
      end
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getrawtransaction failed #{ @coin } for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def setnetworkactive(status)
    begin
      return request("setnetworkactive", status)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "setnetworkactive #{ status } failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def invalidateblock(block_hash)
    begin
      return request("invalidateblock", block_hash)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "invalidateblock #{ block_hash } failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def reconsiderblock(block_hash)
    begin
      return request("reconsiderblock", block_hash)
    rescue Bitcoiner::Client::JSONRPCError => e
      # TODO: intercept specific error messages (e.g. block not found vs. connection error)
      puts "reconsiderblock #{ block_hash } failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): block not found" unless Rails.env.test?
      return
    end
  end

  def submitblock(block_data, block_hash)
    begin
      return request("submitblock", block_data)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "submitblock #{ block_hash } failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def submitheader(header_data)
    begin
      return request("submitheader", header_data)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "submitheader failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblocktemplate(rules)
    begin
      return request("getblocktemplate", rules)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getblocktemplate failed for #{ @coin } #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  private

  def request(*args)
    begin
      @client.request(*args)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise MethodNotFoundError if e.message.include?("Method not found")
      raise TimeOutError if e.message.include?("operation_timedout")
      raise ConnectionError if e.message.include?("couldnt_connect")
      raise NodeInitializingError if e.message.include?("Verifying blocks")
      raise NodeInitializingError if e.message.include?("Loading block index")
      raise
    end
  end
end
