class Api::V1::NodesController < ApplicationController
  def index
    if params[:coin] && ["BTC", "BCH"].include?(params[:coin])
      @nodes = Node.where(coin: params[:coin])
    else
      @nodes = Node.all
    end
    render json: @nodes
  end
end
