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

  def getblockchaininfo
    raise Error, "Set Python node" unless @node != nil
    begin
      return @node.getblockchaininfo()
    rescue Error => e
      raise Error, "getblockchaininfo failed for #{@name_with_version} (id=#{@node_id}): " + e.message
    end
  end

  def getinfo
    raise Error, "Set Python node" unless @node != nil
    begin
      return @node.getinfo()
    rescue Error => e
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

end
