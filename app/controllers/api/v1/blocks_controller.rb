class Api::V1::BlocksController < ApplicationController
  before_action :authenticate_user!, only: :show

  # List of blocks, Bitcoin only
  def index
    respond_to do |format|
      format.json {
        @range = JSON.parse(params["range"])
        @offset = @range[0]
        @limit = @range[1]
        @blocks = Block.where(coin: :btc).order(height: :desc).offset(@offset).limit(@limit)
        response.headers['Content-Range'] = Block.where(coin: :btc).count
        render json: @blocks
      }
      format.csv {
        @start = params[:start] ? params[:start] : 0
        @blocks = Block.where(coin: :btc).where("height >= ?", @start).order(height: :asc)
        send_data @blocks.to_csv, filename: "#{self.controller_name}.csv"
      }
    end
  end

  def show
    render json: @block
  end

end
