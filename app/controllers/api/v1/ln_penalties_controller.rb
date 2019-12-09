class Api::V1::LnPenaltiesController < ApplicationController

  def index
    @ln_penalties = LightningTransaction.joins(:block).order(height: :desc)
    render json: @ln_penalties
  end

end
