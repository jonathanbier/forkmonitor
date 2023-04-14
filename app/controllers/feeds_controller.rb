# frozen_string_literal: true

class FeedsController < ApplicationController
  before_action :set_page

  def blocks_invalid
    respond_to do |format|
      format.rss do
        # Blocks are marked invalid during chaintip check
        latest = Chaintip.joins(:block).order(updated_at: :desc).first
        @blocks_invalid = Block.where('array_length(marked_invalid_by,1) > 0').order(height: :desc) if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
      end
    end
  end

  def inflated_blocks
    respond_to do |format|
      format.rss do
        latest = InflatedBlock.joins(:block).order(updated_at: :desc).first
        @inflated_blocks = InflatedBlock.joins(:block).order(created_at: :desc) if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
      end
    end
  end

  def invalid_blocks
    respond_to do |format|
      format.rss do
        latest = InvalidBlock.joins(:block).order(updated_at: :desc).first
        @invalid_blocks = InvalidBlock.joins(:block).order(height: :desc) if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
      end
    end
  end

  def unknown_pools
    respond_to do |format|
      format.rss do
        latest = Block.order(height: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @unknown_pools = Block.where(pool: nil).where('height > ?',
                                                        latest.height - 10_000).where.not(coinbase_message: nil).order(height: :desc).limit(50)
        end
      end
    end
  end

  def lagging_nodes
    respond_to do |format|
      format.rss do
        latest = Lag.order(updated_at: :desc).first
        @lagging_nodes = Lag.where(publish: true).order(created_at: :desc) if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
      end
    end
  end

  def unreachable_nodes
    respond_to do |format|
      format.rss do
        enabled_nodes = Node.where(enabled: true).order(unreachable_since: :desc, mirror_unreachable_since: :desc)
        @unreachable_nodes = enabled_nodes.where.not(unreachable_since: nil).or(enabled_nodes.where.not(mirror_unreachable_since: nil))
      end
    end
  end

  def version_bits
    respond_to do |format|
      format.rss do
        latest = VersionBit.order(updated_at: :desc).first
        @version_bits = VersionBit.all.order(created_at: :desc) if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
      end
    end
  end

  def stale_candidates
    latest = StaleCandidate.last_updated_cached
    if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
      @page_count = Rails.cache.fetch 'StaleCandidate.feed.count' do
        (StaleCandidate.feed.count / StaleCandidate::PER_PAGE.to_f).ceil
      end

      respond_to do |format|
        format.rss do
          @stale_candidates = StaleCandidate.feed.page_cached(@page)
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
          @ln_penalties = PenaltyTransaction.all_with_block_cached
        end
      end
    end
  end

  def ln_sweeps
    respond_to do |format|
      format.rss do
        latest = SweepTransaction.last_updated_cached
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @page_count = Rails.cache.fetch 'SweepTransaction.count' do
            (SweepTransaction.count / SweepTransaction::PER_PAGE.to_f).ceil
          end
          @ln_sweeps = SweepTransaction.page_with_block_cached(@page)
        end
      end
    end
  end

  def ln_uncoops
    respond_to do |format|
      format.rss do
        latest = MaybeUncoopTransaction.last_updated_cached
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @page_count = Rails.cache.fetch 'MaybeUncoopTransaction.count' do
            (MaybeUncoopTransaction.count / MaybeUncoopTransaction::PER_PAGE.to_f).ceil
          end
          @ln_uncoops = MaybeUncoopTransaction.page_with_block_cached(@page)
        end
      end
    end
  end

  private

  def set_page
    @page = (params[:page] || 1).to_i
    if @page < 1
      render json: 'invalid param', status: :unprocessable_entity
      nil
    end
  end
end
