class Api::V1::InflatedBlocksController < ApplicationController
  before_action :authenticate_user!, only: [:destroy]
  before_action :set_inflated_block, only: [:show, :destroy]

  def index
    if params[:coin]
      coin = params[:coin].downcase.to_sym
      @inflated_blocks = InflatedBlock.joins(:block).where(dismissed_at: nil).where("blocks.coin = ?", Block.coins[coin])
    else
      @inflated_blocks = InflatedBlock.all
    end
    response.headers['Content-Range'] = @inflated_blocks.count
    render json: @inflated_blocks
  end
  
  def show
    render json: @inflated_block
  end

  # Mark as dismissed
  def destroy
    @inflated_block.update dismissed_at: Time.now
    head :no_content
  end
  
  private

  def set_inflated_block
    @inflated_block = InflatedBlock.find(params[:id])
  end
  
  def inflated_block_params
    params.require(:inflated_block)
  end

end