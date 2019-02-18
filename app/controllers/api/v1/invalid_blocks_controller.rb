class Api::V1::InvalidBlocksController < ApplicationController

  def index
    @invalid_blocks = InvalidBlock.all
    response.headers['Content-Range'] = @invalid_blocks.count
    render json: @invalid_blocks
  end

end
