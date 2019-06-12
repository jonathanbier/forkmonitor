class Api::V1::InvalidBlocksController < ApplicationController

  def index
    if params[:coin]
      coin = params[:coin].downcase.to_sym
      @invalid_blocks = InvalidBlock.joins(:block).where("blocks.coin = ?", Block.coins[coin])
    else
      @invalid_blocks = InvalidBlock.all
    end
    response.headers['Content-Range'] = @invalid_blocks.count
    render json: @invalid_blocks
  end

end
