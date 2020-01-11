class Api::V1::LnStatsController < ApplicationController

  def index
    latest = PenaltyTransaction.order(updated_at: :desc).first
    if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
      @ln_stats = {
        count: PenaltyTransaction.count,
        total: PenaltyTransaction.sum(:amount)
      }
      render json: @ln_stats
    end
  end

end
