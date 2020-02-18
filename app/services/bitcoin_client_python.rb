class BitcoinClientPython
  class Error < StandardError
  end

  def initialize(node_id, name_with_version, client_type)
    @client_type = client_type
    @node_id = node_id
    @name_with_version = name_with_version
  end

  def set_python_node(node)
    @node = node
  end

  def getblock(block_hash, verbosity)
    raise Error, "Set Python node" unless @node != nil
    raise Error, "Specify block hash" unless block_hash.present?
    begin
      return @node.getblock(blockhash=block_hash, verbosity=verbosity)
    rescue Error => e
      raise Error, "getblock(#{ block_hash }, #{ verbosity}) failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getblockchaininfo
    raise Error, "Set Python node" unless @node != nil
    begin
      return @node.getblockchaininfo()
    rescue PyCall::PyError => e
      raise Error, "getblockchaininfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getinfo
    raise Error, "Set Python node" unless @node != nil
    begin
      return @node.getinfo()
    rescue NoMethodError => e
      raise Error, "getinfo undefined for #{@name_with_version} (id=#{@node_id}): " + e.message
    rescue PyCall::PyError => e
      raise Error, "getinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getnetworkinfo
    raise Error, "Set Python node" unless @node != nil
    begin
      return @node.getnetworkinfo()
    rescue Error => e
      raise Error, "getnetworkinfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def generate(n)
    raise Error, "Set Python node" unless @node != nil
    begin
      return @node.generatetoaddress(n, "bcrt1qqxm98uduexxmn7f2xxdhvx7u7pkvmpupcl6vys")
    rescue Error => e
      raise Error, "generatetoaddress failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getrawtransaction(hash, verbose = false, block_hash = nil)
    raise Error, "Set Python node" unless @node != nil
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
end
