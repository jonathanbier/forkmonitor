# frozen_string_literal: true

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
      @socket_uri = "tcp://#{rpchost}:#{rpcport}"
      zmq_connect
    else
      @client = Bitcoiner.new(rpcuser, rpcpassword, "#{rpchost}:#{rpcport}")
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
  attr_reader :client

  def recv_array_with_timeout(socket, timeout, command)
    Timeout.timeout(timeout) do
      # Maximum 5 seconds of patience.
      # The use of Thread.interrupt is considered unsafe, but at least we're not
      # locking a database.
      return socket.recv_array
    end
  rescue Timeout::Error => e
    puts "Timeout: #{command}"
    zmq_disconnect
    nil
  end

  def help(command = nil)
    if command.nil?
      request('help')
    else
      request(command)
    end
  end

  def disconnectnode(address, peer_id)
    request('disconnectnode', address, peer_id)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise PeerNotConnected if e.message.include?('Node not found in connected nodes')

    raise Error,
          "disconnectnode(#{address},#{peer_id}) failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getnetworkinfo
    Timeout.timeout(30, TimeOutError) do
      Thread.new { request('getnetworkinfo') }.value
    end
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getnetworkinfo failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getpeerinfo
    request('getpeerinfo')
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getpeerinfo failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockcount
    request('getblockcount')
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getblockcount failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockheight
    raise Error, 'Not implemented' unless @client_type == :libbitcoin

    command = 'blockchain.fetch_last_height'
    zmq_connect unless @zmq_connected
    @socket.send_array [command.b, [1].pack('I'), ''.b]

    res = recv_array_with_timeout(@socket, 5, command)
    return nil if res.nil?

    error_code = res[2][0..3].unpack1('L<')
    throw "#{command} failed #{@coin} with error code: #{error_code}" if error_code.positive?
    res[2][4..].unpack1('L<')
  end

  def getinfo
    # TODO: patch https://github.com/NARKOZ/bitcoiner (which uses https://github.com/typhoeus/typhoeus)
    # to check for timeout.
    # See also: https://adamhooper.medium.com/in-ruby-dont-use-timeout-77d9d4e5a001
    Timeout.timeout(30, TimeOutError) do
      Thread.new { request('getinfo') }.value
    end
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getinfo failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockchaininfo
    Timeout.timeout(30, TimeOutError) do
      Thread.new { request('getblockchaininfo') }.value
    end
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getblockchaininfo failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockhash(height)
    request('getblockhash', height)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getblockhash #{height} failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getbestblockhash
    request('getbestblockhash')
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getbestblockhash failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblock(hash, verbosity, timeout = 30)
    Timeout.timeout(timeout, TimeOutError) do
      Thread.new { request('getblock', hash, verbosity) }.value
    end
  rescue TimeOutError
    raise TimeOutError,
          "getblock(#{hash},#{verbosity}) timed out for #{@coin} #{@name_with_version} (id=#{@node_id})"
  rescue Bitcoiner::Client::JSONRPCError => e
    raise PartialFileError if e.message.include?('partial_file')
    raise BlockPrunedError if e.message.include?('pruned data')
    raise BlockNotFoundError if e.message.include?('Block not found')

    raise Error,
          "getblock(#{hash},#{verbosity}) failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockfrompeer(hash, peer_id)
    request('getblockfrompeer', hash, peer_id)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error,
          "getblockfrompeer(#{hash},#{peer_id}) failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockheader(hash_or_height, verbose = true)
    throw 'Must provide a hash or height' if hash_or_height.nil?
    if @client_type == :libbitcoin
      command = 'blockchain.fetch_block_header'
      zmq_connect unless @zmq_connected
      @socket.send_array [command.b, [1].pack('I'),
                          hash_or_height.is_a?(Numeric) ? [hash_or_height].pack('I') : [hash_or_height.reverse].pack('h*')]
      res = recv_array_with_timeout(@socket, 5, command)
      return nil if res.nil?

      error_code = res[2][0..3].unpack1('L<')
      throw "#{command} failed with error code: #{error_code}" if error_code.positive?
      block_header = res[2][4..]
      block_version = block_header[0..3].unpack1('h*')
      previousblockhash = block_header[4..(4 + 32 - 1)].unpack1('h*').reverse
      block_hash = Digest::SHA2.digest(Digest::SHA2.digest(block_header)).unpack1('h*').reverse

      if hash_or_height.is_a?(Numeric)
        height = hash_or_height
      else
        command = 'blockchain.fetch_block_height'
        zmq_connect unless @zmq_connected
        @socket.send_array [command.b, [1].pack('I'), [block_hash.reverse].pack('h*')]
        res = recv_array_with_timeout(@socket, 5, command)
        return nil if res.nil?

        error_code = res[2][0..3].unpack1('L<')
        throw "#{command} failed with error code: #{error_code}" if error_code.positive?
        height = res[2][4..].unpack1('L<')
      end

      {
        'height' => height,
        'version' => block_version,
        # TODO: get time
        'hash' => block_hash,
        'previousblockhash' => previousblockhash
      }
    else
      hash = hash_or_height
      begin
        request('getblockheader', hash, verbose)
      rescue Bitcoiner::Client::JSONRPCError => e
        raise BlockNotFoundError if e.message.include?('Block not found')

        raise Error,
              "getblockheader(#{hash},#{verbose}) failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
      end
    end
  end

  def getchaintips
    Timeout.timeout(120, TimeOutError) do
      Thread.new { request('getchaintips') }.value
    end
  rescue TimeOutError
    raise TimeOutError, "getchaintips timed out for #{@coin} #{@name_with_version} (id=#{@node_id})"
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getchaintips failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getmempoolinfo
    request('getmempoolinfo')
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getmempoolinfo failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def gettxoutsetinfo
    request('gettxoutsetinfo')
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "gettxoutsetinfo failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getrawtransaction(hash, verbose = false, block_hash = nil)
    if block_hash.present?
      request('getrawtransaction', hash, verbose, block_hash)
    else
      request('getrawtransaction', hash, verbose)
    end
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getrawtransaction failed #{@coin} for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def setnetworkactive(status)
    request('setnetworkactive', status)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error,
          "setnetworkactive #{status} failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def invalidateblock(block_hash)
    request('invalidateblock', block_hash)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error,
          "invalidateblock #{block_hash} failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def reconsiderblock(block_hash)
    request('reconsiderblock', block_hash)
  rescue Bitcoiner::Client::JSONRPCError => e
    # TODO: intercept specific error messages (e.g. block not found vs. connection error)
    unless Rails.env.test?
      puts "reconsiderblock #{block_hash} failed for #{@coin} #{@name_with_version} (id=#{@node_id}): block not found"
    end
    nil
  end

  def submitblock(block_data, block_hash)
    request('submitblock', block_data)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error,
          "submitblock #{block_hash} failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def submitheader(header_data)
    request('submitheader', header_data)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "submitheader failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblocktemplate(rules)
    request('getblocktemplate', rules)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise Error, "getblocktemplate failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  private

  def request(*args)
    Rails.logger.info("RPC #{args.collect do |arg|
                               arg.instance_of?(String) ? arg.truncate(100) : arg
                             end.join(' ')} on #{@coin.upcase} #{@name_with_version} (id=#{@node_id})")
    begin
      @client.request(*args)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise MethodNotFoundError if e.message.include?('Method not found')
      raise TimeOutError if e.message.include?('operation_timedout')
      raise ConnectionError if e.message.include?('couldnt_connect')
      raise NodeInitializingError if e.message.include?('Verifying blocks')
      raise NodeInitializingError if e.message.include?('Loading block index')

      raise
    end
  end
end
