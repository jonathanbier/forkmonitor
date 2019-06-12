class FeedsController < ApplicationController
  before_action :set_coin, only: [:orphan_candidates]

  def invalid_blocks
    respond_to do |format|
      format.rss do
        @invalid_blocks = InvalidBlock.all
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

  def orphan_candidates
    respond_to do |format|
      format.rss do
        @orphan_candidates = OrphanCandidate.where(coin: @coin)
      end
    end
  end

  private

  def set_coin
    @coin = params[:coin].downcase.to_sym
  end
end
