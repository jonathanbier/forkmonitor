# frozen_string_literal: true

class BitcoinClientPython
  include ::BitcoinUtil

  def initialize(node_id, name_with_version, client_type, client_version)
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
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      throw 'Specify node and node_id' if node.nil? || command.nil?
      @node.addnode(node, command)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "addnode(#{node}, #{command}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def createwallet(wallet_name: '', disable_private_keys: false, blank: false, passphrase: '', avoid_reuse: false, descriptors: true)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.createwallet(wallet_name, disable_private_keys, blank, passphrase, avoid_reuse, descriptors)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "createwallet failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def importdescriptors(descriptors)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.importdescriptors(descriptors)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "importdescriptors failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  # Only used in tests
  def bumpfee(tx_id)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::PartialFileError if @mock_partial_file_error
    raise BitcoinUtil::RPC::BlockPrunedError if @mock_block_pruned_error
    raise BitcoinUtil::RPC::Error, 'Specify transaction id' if tx_id.blank?

    begin
      @node.bumpfee(tx_id)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "bumpfee(#{tx_id}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  # TODO: add address, node_id params, this can only be called from Python atm
  def disconnectnode(params)
    address = params['address']
    node_id = params['nodeid']
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      throw 'Specify address or node_id' if address.nil? && node_id.nil?
      if address.nil?
        @node.disconnectnode(nodeid: node_id)
      elsif node_id.nil?
        @node.disconnectnode(address: address)
      else
        @node.disconnectnode(address: address, nodeid: node_id)
      end
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error,
            "disconnectnode(#{address}, #{node_id}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblock(block_hash, verbosity, _timeout = nil)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::PartialFileError if @mock_partial_file_error
    raise BitcoinUtil::RPC::BlockPrunedError if @mock_block_pruned_error
    raise BitcoinUtil::RPC::Error, 'Specify block hash' if block_hash.blank?

    begin
      @node.getblock(blockhash = block_hash, verbosity = verbosity) # rubocop:disable Lint/SelfAssignment,Lint/UselessAssignment
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::BlockNotFoundError if e.message.include?('Block not found')

      raise BitcoinUtil::RPC::Error,
            "getblock(#{block_hash}, #{verbosity}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockhash(height)
    @node.getblockhash(height = height) # rubocop:disable Lint/SelfAssignment
  rescue PyCall::PyError => e
    raise BitcoinUtil::RPC::Error, "getblockhash #{height} failed for #{@name_with_version} (id=#{@node_id}): " + e.message
  end

  def getblockheader(block_hash, verbose = true)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::MethodNotFoundError if @client_version < 120_000
    raise BitcoinUtil::RPC::PartialFileError if @mock_partial_file_error
    raise BitcoinUtil::RPC::Error, 'Specify block hash' if block_hash.blank?

    begin
      @node.getblockheader(blockhash = block_hash, verbose = verbose) # rubocop:disable Lint/SelfAssignment,Lint/UselessAssignment
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error,
            "getblockheader(#{block_hash}, #{verbose}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockchaininfo
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.getblockchaininfo
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "getblockchaininfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getinfo
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.getinfo
    rescue NoMethodError => e
      raise BitcoinUtil::RPC::Error, "getinfo undefined for #{@name_with_version} (id=#{@node_id}): " + e.message
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "getinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getdeploymentinfo
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.getdeploymentinfo
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "getdeploymentinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getindexinfo
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.getindexinfo
    rescue NoMethodError => e
      raise BitcoinUtil::RPC::Error, "getindexinfo undefined for #{@name_with_version} (id=#{@node_id}): " + e.message
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "getindexinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getpeerinfo
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.getpeerinfo
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "getpeerinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getnetworkinfo
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.getnetworkinfo
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "getnetworkinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getnewaddress(address_type = nil)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.getnewaddress('', address_type)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "getnewaddress failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def generate(n_blocks)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      coinbase_dest = @node.get_deterministic_priv_key.address
      @node.generatetoaddress(n_blocks, coinbase_dest, invalid_call: false)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "generatetoaddress failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def generatetoaddress(n_blocks, address)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Specify number of blocks' if n_blocks.nil?
    raise BitcoinUtil::RPC::Error, 'Specify address' if address.nil?

    begin
      @node.generatetoaddress(n_blocks, address, invalid_call: false)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "generatetoaddress failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getchaintips
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.getchaintips
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "getchaintips failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getbestblockhash
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.getbestblockhash
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "getbestblockhash failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getrawtransaction(hash, verbose = false, block_hash = nil)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Specify transaction hash' if hash.blank?

    begin
      if block_hash.present?
        @node.getrawtransaction(hash, verbose, block_hash)
      else
        @node.getrawtransaction(hash, verbose)
      end
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error,
            "getrawtransaction(#{hash}, #{verbose}, #{block_hash}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getmempoolinfo
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.getmempoolinfo
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "getmempoolinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def gettxoutsetinfo
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      info = @node.gettxoutsetinfo
      if @mock_extra_inflation.positive?
        Rails.logger.debug { "Add extra #{@mock_extra_inflation} inflation..." }
        info = info.collect { |k, v| [k, k == 'total_amount' ? (v.to_f + @mock_extra_inflation) : v] }.to_h # rubocop:disable Style/MapToHash
      end
      info
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "gettxoutsetinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def invalidateblock(block_hash)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Specify block hash' if block_hash.blank?

    begin
      @node.invalidateblock(blockhash = block_hash) # rubocop:disable Lint/UselessAssignment
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "invalidateblock(#{block_hash}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def reconsiderblock(block_hash)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Specify block hash' if block_hash.blank?

    begin
      @node.reconsiderblock(blockhash = block_hash) # rubocop:disable Lint/UselessAssignment
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "reconsiderblock(#{block_hash}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def listtransactions
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.listtransactions
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "listtransactions failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def sendrawtransaction(tx)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Specify transaction' if tx.blank?

    begin
      @node.sendrawtransaction(tx)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "sendrawtransaction(#{tx}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def gettransaction(tx)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Specify transaction' if tx.blank?

    begin
      @node.gettransaction(tx)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "gettransaction(#{tx}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def abandontransaction(tx)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Specify transaction' if tx.blank?

    begin
      @node.abandontransaction(tx)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "abandontransaction(#{tx}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def sendtoaddress(destination, amount, comment = '', comment_to = '', subtractfeefromamount = false, replaceable = false)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Specify destination' if destination.blank?
    raise BitcoinUtil::RPC::Error, 'Specify amount' if amount.blank?

    begin
      @node.sendtoaddress(address = destination, amount = amount.to_s, comment = comment, comment_to = comment_to, # rubocop:disable Lint/SelfAssignment,Lint/UselessAssignment
                          subtractfeefromamount = subtractfeefromamount, replaceable = replaceable)                # rubocop:disable Lint/SelfAssignment,Lint/UselessAssignment
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error,
            "sendtoaddress(#{destination}, #{amount}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def testmempoolaccept(txs)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.testmempoolaccept(txs)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "testmempoolaccept failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def walletcreatefundedpsbt(inputs, outputs)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.walletcreatefundedpsbt(inputs, outputs)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "walletcreatefundedpsbt failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def walletprocesspsbt(psbt, sign)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.walletprocesspsbt(psbt, sign)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "walletprocesspsbt failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def finalizepsbt(psbt)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error

    begin
      @node.finalizepsbt(psbt)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "finalizepsbt failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def setnetworkactive(state)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Set state to false or true' unless [false, true].include?(state)

    begin
      @node.setnetworkactive(state)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "setnetworkactive(#{block_hash}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def submitblock(block, block_hash = nil)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Specify block' if block.blank?

    begin
      @node.submitblock(block)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error,
            "submitblock(#{block_hash.presence || block}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def submitheader(header)
    raise BitcoinUtil::RPC::Error, 'Set Python node' if @node.nil?
    raise BitcoinUtil::RPC::ConnectionError if @mock_connection_error
    raise BitcoinUtil::RPC::Error, 'Provide header hex' if header.blank?

    begin
      @node.submitheader(header)
    rescue PyCall::PyError => e
      raise BitcoinUtil::RPC::Error, "submitheader(#{header}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end
end
