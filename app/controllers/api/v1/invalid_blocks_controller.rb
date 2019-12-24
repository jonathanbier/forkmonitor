class Api::V1::InvalidBlocksController < ApplicationController

  before_action :authenticate_user!, only: [:destroy]
  before_action :set_invalid_block, only: [:show, :destroy]

  def index
    if params[:coin]
      coin = params[:coin].downcase.to_sym
      latest = InvalidBlock.joins(:block).where("blocks.coin = ?", Block.coins[coin]).order(updated_at: :desc).first
      if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
        @invalid_blocks = InvalidBlock.joins(:block).where(dismissed_at: nil).where("blocks.coin = ?", Block.coins[coin])
        response.headers['Content-Range'] = @invalid_blocks.count
        render json: @invalid_blocks
      end
    else
      @invalid_blocks = InvalidBlock.all
      response.headers['Content-Range'] = @invalid_blocks.count
      render json: @invalid_blocks
    end
  end

  def show
    render json: @invalid_block
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
