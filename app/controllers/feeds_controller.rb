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
    latest = StaleCandidate.where(coin: @coin).order(updated_at: :desc).first
    if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
      @page = (params[:page] || 1).to_i
      @per_page = Rails.env.production? ? 10 : 2
      @page_count = (StaleCandidate.where(coin: @coin).count / @per_page.to_f).ceil

      respond_to do |format|
        format.rss do
          @stale_candidates = StaleCandidate.where(coin: @coin).order(created_at: :desc).offset((@page - 1) * @per_page).limit(@per_page)
        end
      end
    end
  end

  def ln_penalties
    respond_to do |format|
      format.rss do
        latest = LightningTransaction.order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
          @ln_penalties = []
          if @coin == :btc
            @ln_penalties = LightningTransaction.order(created_at: :desc)
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
