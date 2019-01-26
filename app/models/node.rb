class Node < ApplicationRecord
  belongs_to :block
  belongs_to :common_block, foreign_key: "common_block_id", class_name: "Block", required: false

  default_scope { includes(:block).order("blocks.work desc", name: :asc, version: :desc) }

  scope :bitcoin_by_version, -> { where(coin: "BTC").reorder(version: :desc) }

  def as_json(options = nil)
    fields = [:id, :name, :version, :unreachable_since]
    if options && options[:admin]
      fields << :id << :coin << :rpchost << :rpcuser << :rpcpassword
    end
    super({ only: fields }.merge(options || {})).merge({best_block: block, common_block: common_block})
  end

  def client
    if !@client
      @client = self.class.client_klass.new(self.rpchost, self.rpcuser, self.rpcpassword)
    end
    return @client
  end

  # Update database with latest info from this node
  def poll!
    begin
      networkinfo = client.getnetworkinfo
      blockchaininfo = client.getblockchaininfo
    rescue Bitcoiner::Client::JSONRPCError
      self.update unreachable_since: self.unreachable_since || DateTime.now
      return
    end

    if networkinfo.present?
      self.update(version: networkinfo["version"], peer_count: networkinfo["connections"])
    end

    if blockchaininfo.present?
      ibd = blockchaininfo["initialblockdownload"].present? ?
            blockchaininfo["initialblockdownload"] :
            blockchaininfo["verificationprogress"] < 0.99
      self.update ibd: ibd
    end

    if self.common_height && !self.common_block
      common_block_hash = client.getblockhash(self.common_height)
      common_block_info = client.getblock(common_block_hash)
      common_block = Block.create_with(height: self.common_height, timestamp: common_block_info["mediantime"] || common_block_info["time"], work: common_block_info["chainwork"]).find_or_create_by(block_hash: common_block_info["hash"])
      self.update common_block: common_block
    end

    # Not atomic and called very frequently, so sometimes it tries to insert
    # a block that was already inserted. In that case try again, so it updates
    # the existing block instead.
    begin
      block = Block.find_by(block_hash: blockchaininfo["bestblockhash"])

      if !block
        mediantime = blockchaininfo["mediantime"]
        if !mediantime # Not included in getblockchaininfo for older nodes
          mediantime = client.getblock(blockchaininfo["bestblockhash"])["time"]
        end

        block = build_new_block!(
          blockchaininfo["bestblockhash"],
          blockchaininfo["blocks"],
          mediantime,
          blockchaininfo["chainwork"]
        )
        block.save
      end
    rescue
      raise if Rails.env.test?
      retry
    end
    self.update block: block, unreachable_since: nil
  end

  # Should be run after polling all nodes, otherwise it may find false positives
  def check_if_behind!(node)
    # Return nil if this node is in IBD:
    return nil if self.ibd

    # Return nil if this node has no peers:
    return nil if self.peer_count == 0

    # Return nil if either node is unreachble:
    return nil if self.unreachable_since || node.unreachable_since

    behind = nil
    lag_entry = Lag.find_by(node_a: self, node_b: node)

    # Not behind if at the same block
    if self.block == node.block
      behind = false
    # Compare work:
    elsif self.block.work < node.block.work
      behind = true
    end

    # Remove entry if no longer behind
    if lag_entry && !behind
      lag_entry.destroy
      return nil
    end

    # Store when we first discover the lag:
    if !lag_entry && behind
      lag_entry = Lag.create(node_a: self, node_b: node)
    end

    # Return false if behind but still in grace period:
    return false if lag_entry && ((Time.now - lag_entry.created_at) < (ENV['LAG_GRACE_PERIOD'] || 1 * 60))

    # Send email after grace period
    if lag_entry && !lag_entry.notified_at
      lag_entry.update notified_at: Time.now
      User.all.each do |user|
        UserMailer.with(user: user, lag: lag_entry).lag_email.deliver
      end
    end


    return lag_entry
  end

  def self.poll!
    self.all.each do |node|
      puts "Polling #{ node.coin } node #{node.id} (#{node.name})..." unless Rails.env.test?
      node.poll!
    end
    self.check_laggards!
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
      sleep 5

      self.poll!
      sleep 0.5
    end
  end


  def self.check_laggards!
    nodes = self.bitcoin_by_version
    nodes.drop(1).each do |node|
      lag  = node.check_if_behind!(nodes.first)
      puts "Check if #{ node.version } is behind #{ nodes.first.version }... #{ lag.present? }" if Rails.env.development?
    end
  end

  private

  def self.client_klass
    Rails.env.test? ? BitcoinClientMock : BitcoinClient
  end

  def build_new_block!(block_hash, height, mediantime, chainwork)
    block = Block.new(
      block_hash: block_hash,
      height: height,
      timestamp: mediantime,
      work: chainwork
    )
    # Find parent block, unless this is the first block for a new node (and only for BTC)
    if self.id && self.coin == "BTC"
      block_info = client.getblock(block_hash)
      block.parent = find_or_fetch_parent!(block, block_info["previousblockhash"])
    end
    return block
  end

  def find_or_fetch_parent!(block, previousblockhash)
    parent = Block.find_by(block_hash: previousblockhash)
    if !parent
      block_info = client.getblock(previousblockhash)
      parent = build_new_block!(block_info["hash"], block_info["height"], block_info["mediantime"] || block_info["time"], block_info["chainwork"])
    end
    return parent
  end
end
