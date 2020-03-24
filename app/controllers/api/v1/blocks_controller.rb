class Api::V1::BlocksController < ApplicationController
  before_action :authenticate_user!

  # List of blocks, Bitcoin only
  def index
    @range = JSON.parse(params["range"])
    @offset = @range[0]
    @limit = @range[1]
    @blocks = Block.where(coin: :btc).order(height: :desc).offset(@offset).limit(@limit)
    response.headers['Content-Range'] = Block.where(coin: :btc).count
    render json: @blocks
  end

  def show
    render json: @block
  end

end
