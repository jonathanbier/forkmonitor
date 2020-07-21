require '0mq'
require 'digest'

class BitcoinClient
  class Error < StandardError; end
  class ConnectionError < Error; end
  class PartialFileError < Error; end
  class BlockPrunedError < Error; end

  def initialize(node_id, name_with_version, client_type, rpchost, rpcport, rpcuser, rpcpassword)
    @client_type = client_type
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

  def help
    request("help")
  end

  def getnetworkinfo
    begin
      return request("getnetworkinfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getnetworkinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockcount
    begin
      return request("getblockcount")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getblockcount failed for #{@name_with_version} (id=#{@node_id}): " + e.message
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
    throw "#{ command } failed with error code: #{ error_code }" if error_code > 0
    return res[2][4..-1].unpack("L<")[0]
  end

  def getinfo
    begin
      return request("getinfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockchaininfo
    begin
      return request("getblockchaininfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getblockchaininfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockhash(height)
    begin
      return request("getblockhash", height)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getblockhash #{ height } failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getbestblockhash
    begin
      return request("getbestblockhash")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "getbestblockhash failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblock(hash, verbosity)
    begin
      return request("getblock", hash, verbosity)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise ConnectionError if e.message.include?("couldnt_connect")
      raise PartialFileError if e.message.include?("partial_file")
      raise BlockPrunedError if e.message.include?("pruned data")
      raise Error, "getblock(#{hash},#{verbosity}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockheader(hash_or_height)
    throw "Must provide a hash or height" if hash_or_height.nil?
    if @client_type != :libbitcoin
      hash = hash_or_height
      begin
        return request("getblockheader", hash)
      rescue Bitcoiner::Client::JSONRPCError => e
        raise Error, "getblockheader(#{hash}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
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
      raise Error, "getchaintips failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def gettxoutsetinfo
    begin
      return request("gettxoutsetinfo")
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "gettxoutsetinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
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
      raise Error, "getrawtransaction failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def setnetworkactive(status)
    begin
      return request("setnetworkactive", status)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise ConnectionError if e.message.include?("couldnt_connect")
      raise Error, "setnetworkactive #{ status } failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def invalidateblock(block_hash)
    begin
      return request("invalidateblock", block_hash)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise Error, "invalidateblock #{ block_hash } failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def reconsiderblock(block_hash)
    begin
      return request("reconsiderblock", block_hash)
    rescue Bitcoiner::Client::JSONRPCError => e
      # TODO: intercept specific error messages (e.g. block not found vs. connection error)
      puts "reconsiderblock #{ block_hash } failed for #{@name_with_version} (id=#{@node_id}): block not found" unless Rails.env.test?
      return
    end
  end

  private

  def request(*args)
    @client.request(*args)
  end
end
