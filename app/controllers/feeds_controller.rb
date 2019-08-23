class FeedsController < ApplicationController
  before_action :set_coin, only: [:inflated_blocks, :invalid_blocks, :stale_candidates]

  def inflated_blocks
    respond_to do |format|
      format.rss do
        @inflated_blocks = InflatedBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin])
      end
    end
  end

  def invalid_blocks
    respond_to do |format|
      format.rss do
        @invalid_blocks = InvalidBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin])
      end
    end
  end

  def lagging_nodes
    respond_to do |format|
      format.rss do
        @lagging_nodes = Lag.all
      end
    end
  end

  def version_bits
    respond_to do |format|
      format.rss do
        @version_bits = VersionBit.all
      end
    end
  end

  def stale_candidates
    respond_to do |format|
      format.rss do
        @stale_candidates = StaleCandidate.where(coin: @coin)
      end
    end
  end

  private

  def set_coin
    @coin = params[:coin].downcase.to_sym
  end
end
