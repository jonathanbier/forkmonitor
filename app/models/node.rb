class Node < ApplicationRecord
  belongs_to :block, required: false
  has_many :blocks_first_seen, class_name: "Block", foreign_key: "first_seen_by_id", dependent: :nullify
  has_many :invalid_blocks

  scope :bitcoin_core_by_version, -> { where(coin: "BTC", client_type: :core).where.not(version: nil).order(version: :desc) }
  scope :bitcoin_core_unknown_version, -> { where(coin: "BTC", client_type: :core).where(version: nil) }
  scope :bitcoin_alternative_implementations, -> { where(coin: "BTC"). where.not(client_type: :core) }

  enum client_type: [:core, :bcoin, :knots, :btcd, :libbitcoin, :abc, :sv, :bu]

  scope :bch_by_version, -> { where(coin: "BCH").order(version: :desc) }
  scope :bsv_by_version, -> { where(coin: "BSV").order(version: :desc) }

  def parse_version(v)
    return if v.nil?
    if v[0] == "v"
      digits = v[1..-1].split(".").collect{|d| d.to_i}
      padding = [0] * (4 - digits.size)
      digits.push(*padding)
      return digits[3] + digits[2] * 100 + digits[1] * 10000 + digits[0] * 1000000
    else
      return v
    end
  end

  def name_with_version
    version_arr = self.version.to_s.rjust(8, "0").scan(/.{1,2}/).map(&:to_i)
    return "#{ self.name } #{ version_arr[3] == 0 ? version_arr[0..2].join(".") : version_arr.join(".") }"
  end

  def as_json(options = nil)
    fields = [:id, :name, :version, :unreachable_since, :ibd, :client_type]
    if options && options[:admin]
      fields << :id << :coin << :rpchost << :rpcuser << :rpcpassword
    end
    super({ only: fields }.merge(options || {})).merge({best_block: block})
  end

  def client
    if !@client
      @client = self.class.client_klass.new(self.rpchost, self.rpcuser, self.rpcpassword)
    end
    return @client
  end

  # Update database with latest info from this node
  def poll!
    if self.client_type == :core && self.version.present? && self.version < 100000
      begin
        info = client.getinfo
      rescue Bitcoiner::Client::JSONRPCError
        self.update unreachable_since: self.unreachable_since || DateTime.now
        return
      end
    else # Version is not known the first time
      begin
        blockchaininfo = client.getblockchaininfo
        networkinfo = client.getnetworkinfo
      rescue Bitcoiner::Client::JSONRPCError
        # Try getinfo for ancient nodes:
        begin
          info = client.getinfo
        rescue Bitcoiner::Client::JSONRPCError
          self.update unreachable_since: self.unreachable_since || DateTime.now
          return
        end
      end
    end

    if networkinfo.present?
      self.update(version: parse_version(networkinfo["version"]), peer_count: networkinfo["connections"])
    elsif info.present?
      self.update(version: parse_version(info["version"]), peer_count: info["connections"])
    end

    if blockchaininfo.present?
      if blockchaininfo["initialblockdownload"].present?
        ibd = blockchaininfo["initialblockdownload"]
      elsif blockchaininfo["verificationprogress"].present?
        ibd = blockchaininfo["verificationprogress"] < 0.99
      elsif self.coin == "BTC"
        ibd = info["blocks"] < Block.where(coin: :btc).maximum(:height) - 10
      end
      self.update ibd: ibd
    elsif info.present?
      # getinfo for v0.8.6 doesn't contain initialblockdownload boolean or verificationprogress.
      # As long as we also poll newer nodes, we can infer IBD status from how far behind it is.
      self.update ibd: info["blocks"] < Block.where(coin: :btc).maximum(:height) - 10
    end

    if blockchaininfo.present?
      best_block_hash = blockchaininfo["bestblockhash"]
    elsif info.present?
      best_block_hash = client.getblockhash(info["blocks"])
    end

    block = self.ibd ? nil : find_or_create_block_and_ancestors!(best_block_hash)
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

    begin
      chaintips = client.getchaintips
    rescue Bitcoiner::Client::JSONRPCError
      # Assuming this node doesn't implement it
      return nil
    end
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
    return nil if block.nil?

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
        # Fetch parent block:
        break if !self.id
        puts "Fetch intermediate block at height #{ block.height - 1 }" unless Rails.env.test?
        if self.version >= 120000
          block_info = client.getblockheader(block_info["previousblockhash"])
        else
          block_info = client.getblock(block_info["previousblockhash"])
        end
        parent = Block.create(
          coin: self.coin.downcase.to_sym,
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

    # Collect all transaction ids in main chain up to tip
    block_hash = client.getbestblockhash
    main_tip_txs = []
    while true do
      header = client.getblockheader(block_hash)
      puts "Processing main chain block at height #{ header["height"] }"
      block = client.getblock(block_hash, 1)
      main_tip_txs.concat block["tx"]
      block_hash = header["previousblockhash"]
      break if header["height"] == fork_max_height + 1
    end

    puts "Main chain transactions            : #{ main_txs.size }"
    puts "Fork transactions                  : #{ fork_txs.size }"
    puts "Overlap (same # blocks)            : #{ (main_txs & fork_txs).size }"
    puts "Overlap at tip                     : #{ ((main_txs + main_tip_txs) & fork_txs).size }"
    puts "Unique txs main chain (ex coinbase): #{ ((main_txs + main_tip_txs) - fork_txs).size - fork_len }"
    puts "Unique txs fork chain (ex coinbase): #{ (fork_txs - (main_txs + main_tip_txs)).size - fork_len }"
  end

  def self.poll!
    bitcoin_core_nodes = self.bitcoin_core_by_version
    bitcoin_core_nodes.each do |node|
      puts "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..." unless Rails.env.test?
      node.poll!
    end

    self.bitcoin_core_unknown_version.each do |node|
      puts "Polling #{ node.coin } node #{node.id} (unknown verison)..." unless Rails.env.test?
      node.poll!
    end

    bitcoin_alternative_implementations.each do |node|
      puts "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..." unless Rails.env.test?
      node.poll!
    end

    self.check_laggards!
    self.check_chaintips!
    bitcoin_core_nodes.first.check_versionbits!

    self.bch_by_version.each do |node|
      puts "Polling #{ node.coin } node #{node.id} (#{node.name_with_version})..." unless Rails.env.test?
      node.poll!
    end

    self.bsv_by_version.each do |node|
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
    self.bitcoin_core_by_version.each do |node|
      if node.version.present? && node.version >= 100000 # getchaintips was added in v0.10
        node.check_chaintips!
      end
    end
    self.bitcoin_alternative_implementations.each do |node|
      node.check_chaintips!
    end
    # Look for potential orphan blocks, i.e. more than one block at the same height
    tip_height = Block.where(coin: :btc).maximum(:height)
    Block.select(:height).where(coin: :btc).where("height > ?", tip_height - 100).group(:height).having('count(height) > 1').each do |block|
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
    core_nodes = self.bitcoin_core_by_version
    core_nodes.drop(1).each do |node|
      lag  = node.check_if_behind!(core_nodes.first)
      puts "Check if #{ node.name_with_version } is behind #{ core_nodes.first.name_with_version }... #{ lag.present? }" unless Rails.env.test?
    end

    self.bitcoin_alternative_implementations.each do |node|
      lag  = node.check_if_behind!(core_nodes.first)
      puts "Check if #{ node.name_with_version } is behind #{ core_nodes.first.name_with_version }... #{ lag.present? }" unless Rails.env.test?
    end
  end

  def self.fetch_ancestors!(until_height)
    node = Node.bitcoin_core_by_version.first
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
          coin: self.coin.downcase.to_sym,
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
