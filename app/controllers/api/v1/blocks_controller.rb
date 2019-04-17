class Api::V1::BlocksController < ApplicationController
  before_action :authenticate_user!

  # List of blocks, Bitcoin only
  def index
    @range = JSON.parse(params["range"])
    @offset = @range[0]
    @limit = @range[1]
    @blocks = Block.where(is_btc: true).order(height: :desc).offset(@offset).limit(@limit)
    response.headers['Content-Range'] = Block.where(is_btc: true).count
    render json: @blocks
  end

end
