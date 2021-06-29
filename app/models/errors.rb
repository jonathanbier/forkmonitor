# frozen_string_literal: true

module Errors
  module Node
    class Error < StandardError; end

    class InvalidCoinError < Error; end

    class NoTxIndexError < Error; end

    class TxNotFoundError < Error; end

    class ConnectionError < Error; end

    class PartialFileError < Error; end

    class BlockPrunedError < Error; end

    class BlockNotFoundError < Error; end

    class MethodNotFoundError < Error; end

    class NoMatchingNodeError < Error; end

    class TimeOutError < Error; end

    class NodeInitializingError < Error; end
  end
end
