class BitcoinClientPython
  class Error < StandardError; end
  class ConnectionError < Error; end
  class PartialFileError < Error; end

  def initialize(node_id, name_with_version, client_type)
    @client_type = client_type
    @node_id = node_id
    @name_with_version = name_with_version
    @mock_connection_error = false
    @mock_partial_file_error = false
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

  def addnode(node, command)
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      throw "Specify node and node_id" if node.nil? || command.nil?
      return @node.addnode(node, command)
    rescue Error => e
      raise Error, "addnode(#{ node }, #{ command}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  # TODO: add address, node_id params, this can only be called from Python atm
  def disconnectnode(params)
    address = params["address"]
    node_id = params["nodeid"]
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      throw "Specify address or node_id" if address.nil? && node_id.nil?
      if address.nil?
        return @node.disconnectnode(nodeid: node_id)
      elsif node_id.nil?
        return @node.disconnectnode(address: address)
      else
        return @node.disconnectnode(address: address, nodeid: node_id)
      end
    rescue Error => e
      raise Error, "disconnectnode(#{ address }, #{ node_id}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblock(block_hash, verbosity)
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    raise PartialFileError if @mock_partial_file_error
    raise Error, "Specify block hash" unless block_hash.present?
    begin
      return @node.getblock(blockhash=block_hash, verbosity=verbosity)
    rescue Error => e
      raise Error, "getblock(#{ block_hash }, #{ verbosity}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockchaininfo
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      return @node.getblockchaininfo()
    rescue PyCall::PyError => e
      raise Error, "getblockchaininfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getinfo
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      return @node.getinfo()
    rescue NoMethodError => e
      raise Error, "getinfo undefined for #{@name_with_version} (id=#{@node_id}): " + e.message
    rescue PyCall::PyError => e
      raise Error, "getinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getpeerinfo
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      return @node.getpeerinfo()
    rescue PyCall::PyError => e
      raise Error, "getpeerinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getnetworkinfo
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      return @node.getnetworkinfo()
    rescue Error => e
      raise Error, "getnetworkinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def generate(n)
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      n.times do
        coinbase_dest = @node.getnewaddress()
        @node.generatetoaddress(1, coinbase_dest)
      end
    rescue Error => e
      raise Error, "generatetoaddress failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getchaintips
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      return @node.getchaintips()
    rescue Error => e
      raise Error, "getchaintips failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getpeerinfo
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      return @node.getpeerinfo()
    rescue Error => e
      raise Error, "getpeerinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getbestblockhash
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      return @node.getbestblockhash()
    rescue Error => e
      raise Error, "getbestblockhash failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getrawtransaction(hash, verbose = false, block_hash = nil)
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    raise Error, "Specify transaction hash" unless hash.present?
    begin
      if block_hash.present?
        return @node.getrawtransaction(hash, verbose, block_hash)
      else
        return @node.getrawtransaction(hash, verbose)
      end
    rescue Error => e
      raise Error, "getrawtransaction(#{ hash }, #{ verbose}, #{ block_hash }) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def gettxoutsetinfo
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    begin
      return @node.gettxoutsetinfo()
    rescue Error => e
      raise Error, "gettxoutsetinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def invalidateblock(block_hash)
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    raise Error, "Specify block hash" unless block_hash.present?
    begin
      return @node.invalidateblock(blockhash=block_hash)
    rescue Error => e
      raise Error, "invalidateblock(#{ block_hash }) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def reconsiderblock(block_hash)
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    raise Error, "Specify block hash" unless block_hash.present?
    begin
      return @node.reconsiderblock(blockhash=block_hash)
    rescue Error => e
      raise Error, "reconsiderblock(#{ block_hash }) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def setnetworkactive(state)
    raise Error, "Set Python node" unless @node != nil
    raise ConnectionError if @mock_connection_error
    raise Error, "Set state to false or true" unless [false, true].include?(state)
    begin
      return @node.setnetworkactive(state)
    rescue Error => e
      raise Error, "setnetworkactive(#{ block_hash }) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end
end
