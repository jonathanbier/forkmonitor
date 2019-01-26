class Node < ApplicationRecord
  belongs_to :block
  belongs_to :common_block, foreign_key: "common_block_id", class_name: "Block", required: false

  default_scope { includes(:block).order("blocks.work desc", name: :asc, version: :desc) }

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
      info = client.getnetworkinfo
      block_info = client.getblock(client.getbestblockhash)
    rescue Bitcoiner::Client::JSONRPCError
      self.update unreachable_since: self.unreachable_since || DateTime.now
      return
    end

    if info.present?
      self.update version: info["version"]
    end

    if self.common_height && !self.common_block
      common_block_hash = client.getblockhash(self.common_height)
      common_block_info = client.getblock(common_block_hash)
      common_block = Block.create_with(height: self.common_height, timestamp: common_block_info["time"], work: common_block_info["chainwork"]).find_or_create_by(block_hash: common_block_info["hash"])
      self.update common_block: common_block
    end

    begin
      # Not atomic and called very frequently, so sometimes it tries to insert
      # a block that was already inserted. In that case try again, so it updates
      # the existing block instead.
      block = Block.create_with(height: block_info["height"], timestamp: block_info["time"], work: block_info["chainwork"]).find_or_create_by(block_hash: block_info["hash"])
    rescue
      retry
    end
    self.update block: block, unreachable_since: nil
  end

  def self.poll!
    self.all.each do |node|
      puts "Polling #{ node.coin } node #{node.id} (#{node.name})..." unless Rails.env.test?
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

      self.all.each do |node|
        puts "Polling #{ node.coin } node #{node.id} (#{node.name})..."
        node.poll!
        sleep 0.5
      end
    end
  end

  private

  def self.client_klass
    Rails.env.test? ? BitcoinClientMock : BitcoinClient
  end
end
