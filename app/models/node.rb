class Node < ApplicationRecord
  belongs_to :block, required: false
  belongs_to :common_block, foreign_key: "common_block_id", class_name: "Block", required: false
  belongs_to :first_seen_by, foreign_key: "first_seen_by_id", class_name: "Node", required: false
  has_many :invalid_blocks

  default_scope { includes(:block).order("blocks.work desc", name: :asc, version: :desc) }

  scope :bitcoin_by_version, -> { where(coin: "BTC").reorder(version: :desc) }

  scope :altcoin_by_version, -> { where.not(coin: "BTC").reorder(version: :desc) }

  def name_with_version
    version_arr = self.version.to_s.rjust(8, "0").scan(/.{1,2}/).map(&:to_i)
    return "#{ self.name } #{ version_arr[3] == 0 ? version_arr[0..2].join(".") : version_arr.join(".") }"
  end

  def as_json(options = nil)
    fields = [:id, :name, :version, :unreachable_since, :ibd]
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
      common_block = Block.create_with(
        height: self.common_height,
        mediantime: common_block_info["mediantime"],
        timestamp: common_block_info["time"],
        work: common_block_info["chainwork"],
        version: block_info["version"],
        first_seen_by: self,
        is_btc: self.coin == "BTC"
      ).find_or_create_by(block_hash: common_block_info["hash"])
      self.update common_block: common_block
    end

    block = self.ibd ? nil : find_or_create_block_and_ancestors!(blockchaininfo["bestblockhash"])
    self.update block: block, unreachable_since: nil
  end

  # getchaintips returns all known chaintips for a node, which can be:
  # * active: the current chaintip, added to our database with poll!
  # * valid-fork: valid chain, but not the most proof-of-work
  # * valid-headers: potentially valid chain, but not fully checked due to insufficient proof-of-work
  # * headers-only: same as valid-header, but even less checking done
  # * invalid: checked and found invalid, we want to make sure other nodes don't follow this, because:
  #   1) the other nodes haven't seen it all; or
  #   2) the other nodes did see it and also consider it invalid; or
  #   3) the other nodes haven't bothered to check because it doesn't have enough proof-of-work

  # We check all invalid chaintips against the database, to see if at any point in time
  # any of our other nodes saw this block, found it to have enough proof of work
  # and considered it valid. This can normally happen under two circumstances:
  # 1. the node is unaware of a soft-fork and initially accepts a block that newer
  #    nodes reject
  # 2. the node has a consensus bug
  def check_chaintips!
    # Return nil if node is unreachble or in IBD:
    return nil if self.unreachable_since || self.ibd

    chaintips = client.getchaintips
    chaintips.each do |chaintip|
      case chaintip["status"]
      when "valid-fork"
        find_or_create_block_and_ancestors!(chaintip["hash"]) unless chaintip["height"] < self.block.height - 1000
      when "invalid"
        block = Block.find_by(block_hash: chaintip["hash"])
        if block
          invalid_block = InvalidBlock.find_or_create_by(node: self, block: block)
          if !invalid_block.notified_at
            User.all.each do |user|
              UserMailer.with(user: user, invalid_block: invalid_block).invalid_block_email.deliver
            end
            invalid_block.update notified_at: Time.now
          end
          return block
        end
      end
    end
    return nil
  end

  # Should be run after polling all nodes, otherwise it may find false positives
  def check_if_behind!(node)
    # Return nil if other node is in IBD:
    return nil if node.ibd

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
    return false if lag_entry && ((Time.now - lag_entry.created_at) < (ENV['LAG_GRACE_PERIOD'] || 1 * 60).to_i)

    # Send email after grace period
    if lag_entry && !lag_entry.notified_at
      lag_entry.update notified_at: Time.now
      User.all.each do |user|
        UserMailer.with(user: user, lag: lag_entry).lag_email.deliver
      end
    end


    return lag_entry
  end

  def check_versionbits!
    return nil if self.ibd
    self.reload # Block parent links may be stale otherwise

    threshold = Rails.env.test? ? 2 : ENV['VERSION_BITS_THRESHOLD'].to_i || 50

    block = self.block
    until_height = block.height - (VersionBit::WINDOW - 1)

    versions_window = []

    while block.height >= until_height
      if !block.version.present?
        puts "Missing version for block #{ block.height }"
        exit(1)
      end

      # First three bits of field have no meaning in BIP9. nVersion is a little-endian
      # signed integer that must be greater than 2, which is 0x0010 in binary and 0x02 in hex.
      # By setting the least significant byte to >= 0x02 this requirement is met
      # regardless of the next 3 bytes.
      # This is why nVersion changed from 4 (0x00000004) to 536870912 (0x20000000) for most blocks.
      # In fact, nVersion 4 (0x00000004) would now indicate signalling for a soft fork on bit 26.
      #        mask: 0xe0000000 (bit 0-28)
      # BIP320 mask: 0xe0001fff (loses bit 13-28)
      versions_window.push(("%.32b" % (block.version & ~0xe0000000)).split("").drop(3).reverse().collect{|s|s.to_i})
      break unless block = block.parent
    end

    return nil if versions_window.length != VersionBit::WINDOW # Less than 100 blocks or missing parent info

    versions_tally = versions_window.transpose.map(&:sum)
    throw "Unexpected versions_tally = #{ versions_tally.length } != 29"  if versions_tally.length != 29
    current_alerts = VersionBit.where(deactivate: nil).map{ |vb| [vb.bit, vb] }.to_h
    versions_tally.each_with_index do |tally, bit|
      if tally >= threshold
        if current_alerts[bit].nil?
          puts "Bit #{ bit } exceeds threshold" unless Rails.env.test?
          current_alerts[bit] = VersionBit.create(bit: bit, activate: self.block)
        end
      elsif tally == 0
        current_alert = current_alerts[bit]
        if current_alert.present?
          puts "Turn off alert for bit #{ bit }" unless Rails.env.test?
          current_alert.update deactivate: self.block
        end
      end

      # Send email
      current_alert = current_alerts[bit]
      if current_alert && !current_alert.deactivate && !current_alert.notified_at
        User.all.each do |user|
          UserMailer.with(user: user, bit: bit, tally: tally, window: VersionBit::WINDOW, block: self.block).version_bits_email.deliver
        end
        current_alert.update notified_at: Time.now
      end
    end
  end

  def find_block_ancestors!(child_block, until_height = nil)
    # Prevent new instances from going too far back due to Bitcoin Cash fork blocks:
    oldest_block = [Block.minimum(:height), 560000].max
    block_id = child_block.id
    loop do
      block = Block.find(block_id)
      return if until_height ? block.height == until_height : block.height == oldest_block
      parent = block.parent
      if parent.nil?
        if self.version >= 120000
          block_info = client.getblockheader(block.block_hash)
        else
          block_info = client.getblock(block.block_hash)
        end
        parent = Block.find_by(block_hash: block_info["previousblockhash"])
        block.update parent: parent
      end
      if parent.present?
        return if until_height.nil?
      else
        # Fetch parent block, unless:
        # * this is not a BTC node
        break if !self.id || self.coin != "BTC"
        puts "Fetch intermediate block at height #{ block.height - 1 }" unless Rails.env.test?
        if self.version >= 120000
          block_info = client.getblockheader(block_info["previousblockhash"])
        else
          block_info = client.getblock(block_info["previousblockhash"])
        end
        parent = Block.create(
          is_btc: self.coin == "BTC",
          block_hash: block_info["hash"],
          height: block_info["height"],
          mediantime: block_info["mediantime"],
          timestamp: block_info["time"],
          work: block_info["chainwork"],
          version: block_info["version"],
          first_seen_by: self
        )
        block.update parent: parent
      end
      block_id = parent.id
    end
  end

  def investigate_chaintip(block_hash)
    # Find chaintip:
    chaintips = client.getchaintips
    matches = chaintips.select {|tip| tip["hash"] == block_hash }
    throw "Chaintip #{ block_hash } not found on node #{id} (#{name_with_version})" if matches.empty?
    chaintip = matches.first
    throw "Chaintip is not a valid-fork" unless chaintip["status"] == "valid-fork"
    fork_len = chaintip["branchlen"]
    header = client.getblockheader(block_hash)
    fork_max_height = header["height"]

    # Collect all transaction ids in fork:
    fork_txs = []
    fork_len.times do
      header = client.getblockheader(block_hash)
      puts "Processing fork block at height #{ header["height"] }"
      block = client.getblock(block_hash, 1)
      fork_txs.concat block["tx"]
      block_hash = header["previousblockhash"]
    end

    # Collect all transaction ids in main chain up to same height
    block_hash = client.getblockhash(fork_max_height)
    main_txs = []
    fork_len.times do
      header = client.getblockheader(block_hash)
      puts "Processing main chain block at height #{ header["height"] }"
      block = client.getblock(block_hash, 1)
      main_txs.concat block["tx"]
      block_hash = header["previousblockhash"]
    end

    puts "Main chain transactions: #{ main_txs.size }"
    puts "Fork transactions      : #{ fork_txs.size }"
    puts "Overlap                : #{ (main_txs & fork_txs).size }"
  end

  def self.poll!
    bitcoin_nodes = self.bitcoin_by_version
    bitcoin_nodes.each do |node|
      puts "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..." unless Rails.env.test?
      node.poll!
    end
    self.check_laggards!
    self.check_chaintips!
    bitcoin_nodes.first.check_versionbits!

    self.altcoin_by_version.each do |node|
      puts "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..." unless Rails.env.test?
      node.poll!
    end
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

  def self.check_chaintips!
    self.bitcoin_by_version.each do |node|
      node.check_chaintips!
    end
    # Look for potential orphan blocks, i.e. more than one block at the same height
    tip_height = Block.where(is_btc: true).maximum(:height)
    Block.select(:height).where(is_btc: true).where("height > ?", tip_height - 100).group(:height).having('count(height) > 1').each do |block|
      @orphan_candidate = OrphanCandidate.find_or_create_by(height: block.height)
      if @orphan_candidate.notified_at.nil?
        User.all.each do |user|
          UserMailer.with(user: user, orphan_candidate: @orphan_candidate).orphan_candidate_email.deliver
        end
        @orphan_candidate.update notified_at: Time.now
      end
    end
  end

  def self.check_laggards!
    nodes = self.bitcoin_by_version
    nodes.drop(1).each do |node|
      lag  = node.check_if_behind!(nodes.first)
      puts "Check if #{ node.version } is behind #{ nodes.first.version }... #{ lag.present? }" if Rails.env.development?
    end
  end

  def self.fetch_ancestors!(until_height)
    node = Node.bitcoin_by_version.first
    throw "Node in Initial Blockchain Download" if node.ibd
    node.find_block_ancestors!(node.block, until_height)
  end

  private

  def self.client_klass
    Rails.env.test? ? BitcoinClientMock : BitcoinClient
  end

  def find_or_create_block_and_ancestors!(hash)
    # Not atomic and called very frequently, so sometimes it tries to insert
    # a block that was already inserted. In that case try again, so it updates
    # the existing block instead.
    begin
      block = Block.find_by(block_hash: hash)

      if block.nil?
        if self.version >= 120000
          block_info = client.getblockheader(hash)
        else
          block_info = client.getblock(hash)
        end

        block = Block.create(
          is_btc: self.coin == "BTC",
          block_hash: block_info["hash"],
          height: block_info["height"],
          mediantime: block_info["mediantime"],
          timestamp: block_info["time"],
          work: block_info["chainwork"],
          version: block_info["version"],
          first_seen_by: self
        )
      end

      find_block_ancestors!(block)
    rescue
      raise if Rails.env.test?
      retry
    end
    return block
  end
end
