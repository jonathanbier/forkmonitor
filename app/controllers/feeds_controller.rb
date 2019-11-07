class FeedsController < ApplicationController
  before_action :set_coin, only: [:inflated_blocks, :invalid_blocks, :stale_candidates]

  def inflated_blocks
    respond_to do |format|
      format.rss do
        @inflated_blocks = InflatedBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(created_at: :desc)
      end
    end
  end

  def invalid_blocks
    respond_to do |format|
      format.rss do
        @invalid_blocks = InvalidBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(created_at: :desc)
      end
    end
  end

  def lagging_nodes
    respond_to do |format|
      format.rss do
        @lagging_nodes = Lag.all.order(created_at: :desc)
      end
    end
  end

  def version_bits
    respond_to do |format|
      format.rss do
        @version_bits = VersionBit.all.order(created_at: :desc)
      end
    end
  end

  def stale_candidates
    respond_to do |format|
      format.rss do
        @page = params[:page].present? ? params[:page].to_i : nil
        @per_page = 10
        @page_count = (StaleCandidate.where(coin: @coin).count / @per_page.to_f).ceil
        @stale_candidates = StaleCandidate.where(coin: @coin).order(created_at: :desc).paginate(page: @page || 1, per_page: @per_page)
      end
    end
  end

  private

  def set_coin
    @coin = params[:coin].downcase.to_sym
  end
end
