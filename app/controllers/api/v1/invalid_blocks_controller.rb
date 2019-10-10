class Api::V1::InvalidBlocksController < ApplicationController
  
  before_action :authenticate_user!, only: [:destroy]
  before_action :set_invalid_block, only: [:destroy]

  def index
    if params[:coin]
      coin = params[:coin].downcase.to_sym
      @invalid_blocks = InvalidBlock.joins(:block).where(dismissed_at: nil).where("blocks.coin = ?", Block.coins[coin])
    else
      @invalid_blocks = InvalidBlock.all
    end
    response.headers['Content-Range'] = @invalid_blocks.count
    render json: @invalid_blocks
  end

  # Mark as dismissed
  def destroy
    @invalid_block.update dismissed_at: Time.now
    head :no_content
  end
  
  private

  def set_invalid_block
    @invalid_block = InvalidBlock.find(params[:id])
  end
  
  def invalid_block_params
    params.require(:invalid_block)
  end

end
