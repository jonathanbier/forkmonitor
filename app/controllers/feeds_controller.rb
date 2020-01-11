class FeedsController < ApplicationController
  before_action :set_coin, only: [:inflated_blocks, :invalid_blocks, :stale_candidates, :ln_penalties]

  def inflated_blocks
    respond_to do |format|
      format.rss do
        latest = InflatedBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
          @inflated_blocks = InflatedBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(created_at: :desc)
        end
      end
    end
  end

  def invalid_blocks
    respond_to do |format|
      format.rss do
        latest = InvalidBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
          @invalid_blocks = InvalidBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(created_at: :desc)
        end
      end
    end
  end

  def lagging_nodes
    respond_to do |format|
      format.rss do
        latest = Lag.order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
          @lagging_nodes = Lag.all.order(created_at: :desc)
        end
      end
    end
  end

  def version_bits
    respond_to do |format|
      format.rss do
        latest = VersionBit.order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
          @version_bits = VersionBit.all.order(created_at: :desc)
        end
      end
    end
  end

  def stale_candidates
    latest = StaleCandidate.last_updated_cached(params[:coin])
    if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
      @page = (params[:page] || 1).to_i
      @per_page = Rails.env.production? ? 10 : 2
      @page_count = Rails.cache.fetch "StaleCandidate.count(#{@coin})" do
        (StaleCandidate.where(coin: @coin).count / @per_page.to_f).ceil
      end

      respond_to do |format|
        format.rss do
          @stale_candidates = StaleCandidate.page_cached(@coin, @per_page, @page)
        end
      end
    end
  end

  def ln_penalties
    respond_to do |format|
      format.rss do
        latest = LightningTransaction.last_updated_cached
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
          @ln_penalties = []
          if @coin == :btc
            @ln_penalties = PenaltyTransaction.all_with_block_cached
          end
        end
      end
    end
  end

  private

  def set_coin
    @coin = params[:coin].downcase.to_sym
  end
end
