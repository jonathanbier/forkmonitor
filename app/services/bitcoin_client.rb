# frozen_string_literal: true

require '0mq'
require 'digest'

class BitcoinClient
  include ::BitcoinUtil

  module GetBlockVerbosity
    # These symbols mirror the numeric verbosity levels (0..3) defined in the
    # Bitcoin Core RPC manual: https://bitcoincore.org/en/doc/0.30.0/rpc/blockchain/getblock/
    # The resolver below converts each constant back to the integer that Core expects.
    RAW = :raw
    SUMMARY = :summary
    TRANSACTIONS = :transactions
    TRANSACTIONS_WITH_PREVOUT = :transactions_with_prevout

    DEFAULT = SUMMARY
    VALUES = [RAW, SUMMARY, TRANSACTIONS, TRANSACTIONS_WITH_PREVOUT].freeze
  end

  # Wraps the selected verbosity along with the value that will actually be
  # sent over the wire. `raw_verbose` mirrors the argument we log in error
  # messages, so reviewers can see whether we omitted the parameter entirely or
  # translated it to the legacy integer/boolean form.
  NormalizedGetblockVerbosity = Struct.new(:mode, :rpc_value, :omit_argument) do
    def raw_verbose
      omit_argument ? mode.to_s : "#{mode}=#{rpc_value.inspect}"
    end
  end

  class GetBlockVerbosityResolver
    include GetBlockVerbosity

    def initialize(client_type:, client_version:)
      @client_type = client_type
      @client_version = client_version
    end

    def normalize(input)
      raise ArgumentError, "getblock verbosity must be a symbol, got #{input.inspect}" unless input.is_a?(Symbol)

      mode = validate_mode_symbol(input)
      ensure_supported!(mode)

      rpc_value, omit = rpc_value_for(mode)
      NormalizedGetblockVerbosity.new(mode, rpc_value, omit)
    end

    private

    attr_reader :client_type, :client_version

    def validate_mode_symbol(mode)
      return mode if VALUES.include?(mode)

      raise ArgumentError, "Unknown getblock verbosity: #{mode.inspect}"
    end

    def ensure_supported!(mode)
      case mode
      when TRANSACTIONS
        unless supports_transactions_mode?
          raise BitcoinUtil::RPC::UnsupportedGetblockVerbosity,
                "getblock verbosity #{mode} requires Bitcoin Core 0.15.0 or later"
        end
      when TRANSACTIONS_WITH_PREVOUT
        unless supports_prevout_mode?
          raise BitcoinUtil::RPC::UnsupportedGetblockVerbosity,
                "getblock verbosity #{mode} requires Bitcoin Core 23.0 or later"
        end
      end
    end

    def rpc_value_for(mode)
      return [nil, true] if omit_argument_for?(mode)

      value = if use_integer_argument?
                mode_to_integer(mode)
              else
                mode_to_boolean(mode)
              end

      [value, false]
    end

    def omit_argument_for?(mode)
      mode == SUMMARY && use_implicit_verbose_default?
    end

    def use_integer_argument?
      return false if use_boolean_argument?

      true
    end

    def use_boolean_argument?
      client_type == :core && !client_version.nil? && client_version < 150_000
    end

    def use_implicit_verbose_default?
      client_type == :core && !client_version.nil? && client_version < 100_000
    end

    def mode_to_integer(mode)
      case mode
      when RAW
        0
      when SUMMARY
        1
      when TRANSACTIONS
        2
      when TRANSACTIONS_WITH_PREVOUT
        3
      else
        raise ArgumentError, "Unhandled getblock verbosity mode: #{mode.inspect}"
      end
    end

    def mode_to_boolean(mode)
      case mode
      when RAW
        false
      when SUMMARY
        true
      else
        raise BitcoinUtil::RPC::UnsupportedGetblockVerbosity,
              "getblock verbosity #{mode} is unavailable on boolean-only nodes"
      end
    end

    def supports_transactions_mode?
      return false unless client_type == :core
      return false if client_version.nil?

      client_version >= 150_000
    end

    def supports_prevout_mode?
      return false unless client_type == :core
      return false if client_version.nil?

      client_version >= 230_000
    end
  end

  def initialize(node_id, name_with_version, client_type, client_version, rpchost, rpcport, rpcuser, rpcpassword)
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
  rescue Timeout::Error
    Rails.logger.info "Timeout: #{command}"
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
    raise BitcoinUtil::RPC::PeerNotConnected if e.message.include?('Node not found in connected nodes')

    raise BitcoinUtil::RPC::Error,
          "disconnectnode(#{address},#{peer_id}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getnetworkinfo
    Timeout.timeout(30, BitcoinUtil::RPC::TimeOutError) do
      Thread.new { request('getnetworkinfo') }.value
    end
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getnetworkinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getpeerinfo
    request('getpeerinfo')
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getpeerinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockcount
    request('getblockcount')
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getblockcount failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockheight
    raise BitcoinUtil::RPC::Error, 'Not implemented' unless @client_type == :libbitcoin

    command = 'blockchain.fetch_last_height'
    zmq_connect unless @zmq_connected
    @socket.send_array [command.b, [1].pack('I'), ''.b]

    res = recv_array_with_timeout(@socket, 5, command)
    return nil if res.nil?

    error_code = res[2][0..3].unpack1('L<')
    throw "#{command} failed with error code: #{error_code}" if error_code.positive?
    res[2][4..].unpack1('L<')
  end

  def getinfo
    # TODO: patch https://github.com/NARKOZ/bitcoiner (which uses https://github.com/typhoeus/typhoeus)
    # to check for timeout.
    # See also: https://adamhooper.medium.com/in-ruby-dont-use-timeout-77d9d4e5a001
    Timeout.timeout(30, BitcoinUtil::RPC::TimeOutError) do
      Thread.new { request('getinfo') }.value
    end
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockchaininfo
    Timeout.timeout(30, BitcoinUtil::RPC::TimeOutError) do
      Thread.new { request('getblockchaininfo') }.value
    end
  rescue JSON::ParserError
    raise BitcoinUtil::RPC::Error, "getblockchaininfo failed to parse JSON for #{@name_with_version} (id=#{@node_id}): " + e.message
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getblockchaininfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockhash(height)
    Timeout.timeout(30, BitcoinUtil::RPC::TimeOutError) do
      Thread.new { request('getblockhash', height) }.value
    end
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getblockhash #{height} failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getbestblockhash
    request('getbestblockhash')
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getbestblockhash failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblock(hash, verbosity = GetBlockVerbosity::SUMMARY, timeout = 30)
    normalized = getblock_verbosity_resolver.normalize(verbosity)
    raw_verbose = normalized.raw_verbose

    Timeout.timeout(timeout, BitcoinUtil::RPC::TimeOutError) do
      Thread.new do
        rpc_args = ['getblock', hash]
        rpc_args << normalized.rpc_value unless normalized.omit_argument

        request(*rpc_args)
      end.value
    end
  rescue BitcoinUtil::RPC::TimeOutError
    raise BitcoinUtil::RPC::TimeOutError,
          "getblock(#{hash},#{raw_verbose}) timed out for #{@name_with_version} (id=#{@node_id})"
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::PartialFileError if e.message.include?('partial_file')
    raise BitcoinUtil::RPC::BlockPrunedError if e.message.include?('pruned data')
    raise BitcoinUtil::RPC::BlockNotFullyDownloadedError if e.message.include?('not fully downloaded')
    raise BitcoinUtil::RPC::BlockNotFoundError if e.message.include?('Block not found')

    raise BitcoinUtil::RPC::Error,
          "getblock(#{hash},#{raw_verbose}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockfrompeer(hash, peer_id)
    request('getblockfrompeer', hash, peer_id)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error,
          "getblockfrompeer(#{hash},#{peer_id}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
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
        raise BitcoinUtil::RPC::BlockNotFoundError if e.message.include?('Block not found')

        raise BitcoinUtil::RPC::Error,
              "getblockheader(#{hash},#{verbose}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
      end
    end
  end

  def getchaintips
    Timeout.timeout(120, BitcoinUtil::RPC::TimeOutError) do
      Thread.new { request('getchaintips') }.value
    end
  rescue BitcoinUtil::RPC::TimeOutError
    raise BitcoinUtil::RPC::TimeOutError, "getchaintips timed out for #{@name_with_version} (id=#{@node_id})"
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getchaintips failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getdeploymentinfo
    Timeout.timeout(30, BitcoinUtil::RPC::TimeOutError) do
      Thread.new { request('getdeploymentinfo') }.value
    end
  rescue JSON::ParserError
    raise BitcoinUtil::RPC::Error, "getdeploymentinfo failed to parse JSON for #{@name_with_version} (id=#{@node_id}): " + e.message
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getdeploymentinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getindexinfo
    request('getindexinfo')
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getindexinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getmempoolinfo
    Timeout.timeout(30, BitcoinUtil::RPC::TimeOutError) do
      Thread.new { request('getmempoolinfo') }.value
    end
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getmempoolinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def gettxoutsetinfo
    request('gettxoutsetinfo')
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "gettxoutsetinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getrawtransaction(hash, verbose = false, block_hash = nil)
    if block_hash.present?
      request('getrawtransaction', hash, verbose, block_hash)
    else
      request('getrawtransaction', hash, verbose)
    end
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error, "getrawtransaction failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def setnetworkactive(status)
    request('setnetworkactive', status)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error,
          "setnetworkactive #{status} failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def invalidateblock(block_hash)
    request('invalidateblock', block_hash)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error,
          "invalidateblock #{block_hash} failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def reconsiderblock(block_hash)
    request('reconsiderblock', block_hash)
  rescue Bitcoiner::Client::JSONRPCError
    # TODO: intercept specific error messages (e.g. block not found vs. connection error)
    Rails.logger.info "reconsiderblock #{block_hash} failed for #{@name_with_version} (id=#{@node_id}): block not found" unless Rails.env.test?
    nil
  end

  def submitblock(block_data, block_hash)
    request('submitblock', block_data)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::Error,
          "submitblock #{block_hash} failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def submitheader(header_data)
    request('submitheader', header_data)
  rescue Bitcoiner::Client::JSONRPCError => e
    raise BitcoinUtil::RPC::PreviousHeaderMissing if e.message.include?('Must submit previous header')

    raise BitcoinUtil::RPC::Error, "submitheader failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  private

  def getblock_verbosity_resolver
    @getblock_verbosity_resolver ||= GetBlockVerbosityResolver.new(client_type: @client_type, client_version: @client_version)
  end

  def request(*args)
    Rails.logger.info("RPC #{args.collect do |arg|
                               arg.instance_of?(String) ? arg.truncate(100) : arg
                             end.join(' ')} on #{@name_with_version} (id=#{@node_id})")
    begin
      @client.request(*args)
    rescue Bitcoiner::Client::JSONRPCError => e
      raise BitcoinUtil::RPC::MethodNotFoundError if e.message.include?('Method not found')
      raise BitcoinUtil::RPC::TimeOutError if e.message.include?('operation_timedout')
      raise BitcoinUtil::RPC::ConnectionError if e.message.include?('couldnt_connect')
      raise BitcoinUtil::RPC::NodeInitializingError if e.message.include?('Verifying blocks')
      raise BitcoinUtil::RPC::NodeInitializingError if e.message.include?('Loading block index')
      raise BitcoinUtil::RPC::NodeInitializingError if e.message.include?('Pruning blockstore')

      raise
    end
  end
end
