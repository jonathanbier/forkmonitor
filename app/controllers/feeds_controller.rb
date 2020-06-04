class FeedsController < ApplicationController
  before_action :set_coin, only: [:blocks_invalid, :inflated_blocks, :invalid_blocks, :stale_candidates, :ln_penalties, :ln_sweeps, :ln_uncoops]

  def blocks_invalid
    respond_to do |format|
      format.rss do
        # Blocks are marked invalid during chaintip check
        latest = Chaintip.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @blocks_invalid = Block.where("blocks.coin = ?", Block.coins[@coin]).where("array_length(marked_invalid_by,1) > 0").order(height: :desc)
        end
      end
    end
  end

  def inflated_blocks
    respond_to do |format|
      format.rss do
        latest = InflatedBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @inflated_blocks = InflatedBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(created_at: :desc)
        end
      end
    end
  end

  def invalid_blocks
    respond_to do |format|
      format.rss do
        latest = InvalidBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @invalid_blocks = InvalidBlock.joins(:block).where("blocks.coin = ?", Block.coins[@coin]).order(height: :desc)
        end
      end
    end
  end

  def lagging_nodes
    respond_to do |format|
      format.rss do
        latest = Lag.order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @lagging_nodes = Lag.where(publish: true).order(created_at: :desc)
        end
      end
    end
  end

  def unreachable_nodes
    respond_to do |format|
      format.rss do
        @unreachable_nodes = Node.where(enabled: true).where.not(unreachable_since: nil).order(unreachable_since: :desc)
        latest = @unreachable_nodes.first
        if stale?(etag: latest.try(:unreachable_since), last_modified: latest.try(:unreachable_since))
        end
      end
    end
  end

  def version_bits
    respond_to do |format|
      format.rss do
        latest = VersionBit.order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @version_bits = VersionBit.all.order(created_at: :desc)
        end
      end
    end
  end

  def stale_candidates
    latest = StaleCandidate.last_updated_cached(params[:coin])
    if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
      @page = (params[:page] || 1).to_i
      @page_count = Rails.cache.fetch "StaleCandidate.count(#{@coin})" do
        (StaleCandidate.where(coin: @coin).count / StaleCandidate::PER_PAGE.to_f).ceil
      end

      respond_to do |format|
        format.rss do
          @stale_candidates = StaleCandidate.page_cached(@coin, @page)
        end
      end
    end
  end

  def ln_penalties
    respond_to do |format|
      format.rss do
        latest = PenaltyTransaction.last_updated_cached
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @ln_penalties = []
          if @coin == :btc
            @ln_penalties = PenaltyTransaction.all_with_block_cached
          end
        end
      end
    end
  end

  def ln_sweeps
    respond_to do |format|
      format.rss do
        latest = SweepTransaction.last_updated_cached
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @ln_sweeps = []
          if @coin == :btc
            @page = (params[:page] || 1).to_i
            @page_count = Rails.cache.fetch "SweepTransaction.count" do
              (SweepTransaction.count / SweepTransaction::PER_PAGE.to_f).ceil
            end
            @ln_sweeps = SweepTransaction.page_with_block_cached(@page)
          end
        end
      end
    end
  end

  def ln_uncoops
    respond_to do |format|
      format.rss do
        latest = MaybeUncoopTransaction.last_updated_cached
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @ln_uncoops = []
          if @coin == :btc
            @page = (params[:page] || 1).to_i
            @page_count = Rails.cache.fetch "MaybeUncoopTransaction.count" do
              (MaybeUncoopTransaction.count / MaybeUncoopTransaction::PER_PAGE.to_f).ceil
            end
            @ln_uncoops = MaybeUncoopTransaction.page_with_block_cached(@page)
          end
        end
      end
    end
  end
end
