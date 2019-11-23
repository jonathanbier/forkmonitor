class Api::V1::LnPenaltiesController < ApplicationController

  def index
    @ln_penalties = LightningTransaction.order(created_at: :desc)
    render json: @ln_penalties
  end

end
