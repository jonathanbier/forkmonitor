class Api::V1::NodesController < ApplicationController
  def index
    if params[:coin] && ["BTC", "BCH"].include?(params[:coin].upcase)
      @nodes = Node.where(coin: params[:coin].upcase)
    else
      @nodes = Node.all
    end
    render json: @nodes
  end
end
