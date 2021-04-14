class Api::V1::SoftforksController < ApplicationController
  before_action :set_coin

  def index
    render json: Softfork.where(coin: @coin)
  end

end
