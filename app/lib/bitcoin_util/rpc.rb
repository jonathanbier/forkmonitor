# frozen_string_literal: true

module BitcoinUtil
  module RPC
    class Error < StandardError; end

    class NoTxIndexError < Error; end

    class TxNotFoundError < Error; end

    class ConnectionError < Error; end

    class PartialFileError < Error; end

    class BlockPrunedError < Error; end

    class BlockNotFullyDownloadedError < Error; end

    class BlockNotFoundError < Error; end

    class MethodNotFoundError < Error; end

    class TimeOutError < Error; end

    class NodeInitializingError < Error; end

    class PeerNotConnected < Error; end

    class PreviousHeaderMissing < Error; end

    class UnsupportedGetblockVerbosity < Error; end

    # Errors not directly from Bitcoin RPC (should be moved elsewhere)
    class InvalidCoinError < Error; end
  end
end
