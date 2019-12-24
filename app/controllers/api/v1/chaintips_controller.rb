class Api::V1::ChaintipsController < ApplicationController
  def index_coin
    latest = Chaintip.where(coin: params[:coin].downcase).order(updated_at: :desc).first
    if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at), public: true)
      @chaintips = Chaintip.where(status: "active", coin: params[:coin].downcase, parent_chaintip: nil).includes(:block).order("blocks.work desc", "parent_chaintip_id desc")
      render json: @chaintips.uniq{ |s| s.block.block_hash }
    end
  end
end
