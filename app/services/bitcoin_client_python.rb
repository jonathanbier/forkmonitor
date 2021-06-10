# frozen_string_literal: true

class BitcoinClientPython
  class Error < StandardError; end

  class ConnectionError < Error; end

  class TimeOutError < Error; end

  class PartialFileError < Error; end

  class BlockPrunedError < Error; end

  class BlockNotFoundError < Error; end

  class MethodNotFoundError < Error; end

  class NodeInitializingError < Error; end

  def initialize(node_id, name_with_version, coin, client_type, client_version)
    @coin = coin
    @client_type = client_type
    @client_version = client_version
    @node_id = node_id
    @name_with_version = name_with_version
    @mock_connection_error = false
    @mock_block_pruned_error = false
    @mock_partial_file_error = false
    @mock_extra_inflation = 0
  end

  def set_python_node(node)
    @node = node
  end

  def mock_connection_error(status)
    @mock_connection_error = status
  end

  def mock_partial_file_error(status)
    @mock_partial_file_error = status
  end

  def mock_set_extra_inflation(amount)
    @mock_extra_inflation = amount
  end

  def mock_block_pruned_error(status)
    @mock_block_pruned_error = status
  end

  def mock_version(version)
    @client_version = version
  end

  def addnode(node, command)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      throw 'Specify node and node_id' if node.nil? || command.nil?
      @node.addnode(node, command)
    rescue Error => e
      raise Error, "addnode(#{node}, #{command}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def createwallet(wallet_name: '', disable_private_keys: false, blank: false, passphrase: '', avoid_reuse: false, descriptors: true)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.createwallet(wallet_name, disable_private_keys, blank, passphrase, avoid_reuse, descriptors)
    rescue PyCall::PyError => e
      raise Error, "createwallet failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def importdescriptors(descriptors)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.importdescriptors(descriptors)
    rescue PyCall::PyError => e
      raise Error, "importdescriptors failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  # Only used in tests
  def bumpfee(tx_id)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise PartialFileError if @mock_partial_file_error
    raise BlockPrunedError if @mock_block_pruned_error
    raise Error, 'Specify transaction id' unless tx_id.present?

    begin
      @node.bumpfee(tx_id)
    rescue Error => e
      raise Error, "bumpfee(#{tx_id}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  # TODO: add address, node_id params, this can only be called from Python atm
  def disconnectnode(params)
    address = params['address']
    node_id = params['nodeid']
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      throw 'Specify address or node_id' if address.nil? && node_id.nil?
      if address.nil?
        @node.disconnectnode(nodeid: node_id)
      elsif node_id.nil?
        @node.disconnectnode(address: address)
      else
        @node.disconnectnode(address: address, nodeid: node_id)
      end
    rescue Error => e
      raise Error,
            "disconnectnode(#{address}, #{node_id}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblock(block_hash, verbosity, _timeout = nil)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise PartialFileError if @mock_partial_file_error
    raise BlockPrunedError if @mock_block_pruned_error
    raise Error, 'Specify block hash' unless block_hash.present?

    begin
      @node.getblock(blockhash = block_hash, verbosity = verbosity)
    rescue PyCall::PyError => e
      raise BlockNotFoundError if e.message.include?('Block not found')
    rescue Error => e
      raise Error,
            "getblock(#{block_hash}, #{verbosity}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockhash(height)
    @node.getblockhash(height = height)
  rescue Error => e
    raise Error, "getblockhash #{height} failed for #{@coin} #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockheader(block_hash, verbose = true)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise MethodNotFoundError if @client_version < 120_000
    raise PartialFileError if @mock_partial_file_error
    raise Error, 'Specify block hash' unless block_hash.present?

    begin
      @node.getblockheader(blockhash = block_hash, verbose = verbose)
    rescue Error => e
      raise Error,
            "getblockheader(#{block_hash}, #{verbose}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockchaininfo
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.getblockchaininfo
    rescue PyCall::PyError => e
      raise Error, "getblockchaininfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getinfo
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.getinfo
    rescue NoMethodError => e
      raise Error, "getinfo undefined for #{@name_with_version} (id=#{@node_id}): " + e.message
    rescue PyCall::PyError => e
      raise Error, "getinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getpeerinfo
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.getpeerinfo
    rescue PyCall::PyError => e
      raise Error, "getpeerinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getnetworkinfo
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.getnetworkinfo
    rescue Error => e
      raise Error, "getnetworkinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getnewaddress
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.getnewaddress
    rescue Error => e
      raise Error, "getnewaddress failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def generate(n)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      coinbase_dest = @node.get_deterministic_priv_key.address
      @node.generatetoaddress(n, coinbase_dest)
    rescue Error => e
      raise Error, "generatetoaddress failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def generatetoaddress(n, address)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.generatetoaddress(n, address)
    rescue Error => e
      raise Error, "generatetoaddress failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getchaintips
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.getchaintips
    rescue Error => e
      raise Error, "getchaintips failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getpeerinfo
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.getpeerinfo
    rescue Error => e
      raise Error, "getpeerinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getbestblockhash
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.getbestblockhash
    rescue Error => e
      raise Error, "getbestblockhash failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getrawtransaction(hash, verbose = false, block_hash = nil)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise Error, 'Specify transaction hash' unless hash.present?

    begin
      if block_hash.present?
        @node.getrawtransaction(hash, verbose, block_hash)
      else
        @node.getrawtransaction(hash, verbose)
      end
    rescue Error => e
      raise Error,
            "getrawtransaction(#{hash}, #{verbose}, #{block_hash}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getmempoolinfo
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.getmempoolinfo
    rescue Error => e
      raise Error, "getmempoolinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def gettxoutsetinfo
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      info = @node.gettxoutsetinfo
      if @mock_extra_inflation.positive?
        info = info.collect { |k, v| [k, k == 'total_amount' ? (v.to_f + @mock_extra_inflation) : v] }.to_h
      end
      info
    rescue Error => e
      raise Error, "gettxoutsetinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def invalidateblock(block_hash)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise Error, 'Specify block hash' unless block_hash.present?

    begin
      @node.invalidateblock(blockhash = block_hash)
    rescue Error => e
      raise Error, "invalidateblock(#{block_hash}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def reconsiderblock(block_hash)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise Error, 'Specify block hash' unless block_hash.present?

    begin
      @node.reconsiderblock(blockhash = block_hash)
    rescue Error => e
      raise Error, "reconsiderblock(#{block_hash}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def listtransactions
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.listtransactions
    rescue Error => e
      raise Error, "listtransactions failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def sendrawtransaction(tx)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise Error, 'Specify transaction' unless tx.present?

    begin
      @node.sendrawtransaction(tx)
    rescue Error => e
      raise Error, "sendrawtransaction(#{tx}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def gettransaction(tx)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise Error, 'Specify transaction' unless tx.present?

    begin
      @node.gettransaction(tx)
    rescue Error => e
      raise Error, "gettransaction(#{tx}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def abandontransaction(tx)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise Error, 'Specify transaction' unless tx.present?

    begin
      @node.abandontransaction(tx)
    rescue Error => e
      raise Error, "abandontransaction(#{tx}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def sendtoaddress(destination, amount, comment = '', comment_to = '', subtractfeefromamount = false, replaceable = false)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise Error, 'Specify destination' unless destination.present?
    raise Error, 'Specify amount' unless amount.present?

    begin
      @node.sendtoaddress(address = destination, amount = amount.to_s, comment = comment, comment_to = comment_to,
                          subtractfeefromamount = subtractfeefromamount, replaceable = replaceable)
    rescue Error => e
      raise Error,
            "sendtoaddress(#{destination}, #{amount}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def testmempoolaccept(txs)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.testmempoolaccept(txs)
    rescue Error => e
      raise Error, "testmempoolaccept failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def walletcreatefundedpsbt(inputs, outputs)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.walletcreatefundedpsbt(inputs, outputs)
    rescue Error => e
      raise Error, "walletcreatefundedpsbt failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def walletprocesspsbt(psbt, sign)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.walletprocesspsbt(psbt, sign)
    rescue Error => e
      raise Error, "walletprocesspsbt failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def finalizepsbt(psbt)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error

    begin
      @node.finalizepsbt(psbt)
    rescue Error => e
      raise Error, "finalizepsbt failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def setnetworkactive(state)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise Error, 'Set state to false or true' unless [false, true].include?(state)

    begin
      @node.setnetworkactive(state)
    rescue Error => e
      raise Error, "setnetworkactive(#{block_hash}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def submitblock(block, block_hash = nil)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise Error, 'Specify block' unless block.present?

    begin
      @node.submitblock(block)
    rescue Error => e
      raise Error,
            "submitblock(#{block_hash.presence || block}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def submitheader(header)
    raise Error, 'Set Python node' if @node.nil?
    raise ConnectionError if @mock_connection_error
    raise Error, 'Provide header hex' unless header.present?

    begin
      @node.submitheader(header)
    rescue Error => e
      raise Error, "submitheader(#{header}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end
end
