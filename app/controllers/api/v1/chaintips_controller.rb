class Api::V1::ChaintipsController < ApplicationController
  def index_coin
    @chaintips = Chaintip.where(status: "active", coin: params[:coin].downcase, parent_chaintip: nil).includes(:block).order("blocks.work desc", "parent_chaintip_id desc")

    render json: @chaintips.uniq{ |s| s.block.block_hash }
  end
end
