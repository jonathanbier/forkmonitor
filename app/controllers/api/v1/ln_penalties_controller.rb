class Api::V1::LnPenaltiesController < ApplicationController

  def index
    latest = LightningTransaction.order(updated_at: :desc).first
    if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
      @ln_penalties = LightningTransaction.joins(:block).order(height: :desc)
      render json: @ln_penalties
    end
  end

end
