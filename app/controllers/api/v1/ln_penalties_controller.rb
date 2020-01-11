class Api::V1::LnPenaltiesController < ApplicationController

  def index
    latest = PenaltyTransaction.last_updated_cached
    if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
      render json: Rails.cache.fetch('api/v1/ln_penalties.json') {
        PenaltyTransaction.all_with_block_cached.to_json
      }
    end
  end

end
