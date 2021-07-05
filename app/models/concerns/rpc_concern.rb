# frozen_string_literal: true

# This is designed to work on the Node class. It could be made slightly more
# generic by making it also work on self.node.

# Methods assume the existence of:
# * coin (:btc, etc)
# * client_type (:core, etc)
# * client or mirror_client

# It also needs access to the node list (maybe this should be refactored out)
# * first_with_txindex

module RpcConcern
  extend ActiveSupport::Concern
  class_methods do
    def getrawtransaction(tx_id, coin, verbose = false, block_hash = nil)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      first_with_txindex(coin).getrawtransaction(tx_id, verbose, block_hash)
    end
  end

  def rpc_getblocktemplate
    if version >= 130_100
      client.getblocktemplate({ rules: ['segwit'] })
    else
      client.getblocktemplate({ rules: [] })
    end
  end

  def getblock(block_hash, verbosity, use_mirror = false, timeout = nil)
    throw 'Specify block hash' if block_hash.nil?
    throw 'Specify verbosity' if verbosity.nil?
    client = use_mirror ? mirror_client : self.client
    # https://github.com/bitcoin/bitcoin/blob/master/doc/release-notes/release-notes-0.15.0.md#low-level-rpc-changes
    # * argument verbosity was called "verbose" in older versions, but we use a positional argument
    # * verbose was a boolean until Bitcoin Core 0.15.0
    verbosity = verbosity.positive? if core? && version <= 149_999
    client.getblock(block_hash, verbosity, timeout)
  end

  def getblockheader(block_hash, verbose = true, use_mirror = false)
    throw 'Specify block hash' if block_hash.nil?
    client = use_mirror ? mirror_client : self.client
    client.getblockheader(block_hash, verbose)
  end

  # Returns false if node is not reachable. Returns nil if current mirror_block is missing.
  def restore_mirror
    mirror_client.setnetworkactive(true)
    return if mirror_block.nil?

    # Reconsider all invalid chaintips above the currently active one:
    chaintips = mirror_client.getchaintips
    active_chaintip = chaintips.find { |t| t['status'] == 'active' }
    throw "#{coin} mirror node  does not have an active chaintip" if active_chaintip.nil?
    chaintips.select { |t| t['status'] == 'invalid' && t['height'] >= active_chaintip['height'] }.each do |t|
      mirror_client.reconsiderblock(t['hash'])
    end
  rescue BitcoinUtil::RPC::ConnectionError, BitcoinUtil::RPC::NodeInitializingError, BitcoinUtil::RPC::TimeOutError
    update mirror_unreachable_since: Time.zone.now, last_polled_mirror_at: Time.zone.now
    false
  end

  def get_mirror_active_tip
    mirror_client.getchaintips.find do |t|
      t['status'] == 'active'
    end
  rescue BitcoinUtil::RPC::TimeOutError
    update mirror_unreachable_since: Time.zone.now, last_polled_mirror_at: Time.zone.now
    []
  end

  def getrawtransaction(tx_id, verbose = false, block_hash = nil)
    if core? && version && version >= 160_000
      client.getrawtransaction(tx_id, verbose, block_hash)
    else
      client.getrawtransaction(tx_id, verbose)
    end
  rescue BitcoinUtil::RPC::Error
    # TODO: check error more precisely
    raise BitcoinUtil::RPC::TxNotFoundError,
          "Transaction #{tx_id} #{block_hash.present? ? "in block #{block_hash}" : ''} not found on node #{id} (#{name_with_version})"
  end
end
