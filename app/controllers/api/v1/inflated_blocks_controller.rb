class Api::V1::InflatedBlocksController < ApplicationController

  def index
    if params[:coin]
      coin = params[:coin].downcase.to_sym
      @inflated_blocks = InflatedBlock.joins(:block).where("blocks.coin = ?", Block.coins[coin])
    else
      @inflated_blocks = InflatedBlock.all
    end
    response.headers['Content-Range'] = @inflated_blocks.count
    render json: @inflated_blocks
  end

end
