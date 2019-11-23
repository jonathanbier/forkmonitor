class Api::V1::LnPenaltiesController < ApplicationController

  def index
    @ln_penalties = LightningTransaction.all
    render json: @ln_penalties
  end

end
