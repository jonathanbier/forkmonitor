class Api::V1::LnStatsController < ApplicationController

  def index
    @ln_stats = {
      count: LightningTransaction.count,
      total: LightningTransaction.sum(:amount)
    }
    render json: @ln_stats
  end

end
