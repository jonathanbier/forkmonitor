class Api::V1::ChaintipsController < ApplicationController
  before_action :set_coin

  def index_coin
    latest = Chaintip.where(coin: @coin).order(updated_at: :desc).first
    if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
      render json: Rails.cache.fetch("Chaintip.#{params[:coin].downcase}.index.json") {
        @chaintips = Chaintip.where(status: "active", coin: @coin, parent_chaintip: nil).includes(:block).order("blocks.work desc", "parent_chaintip_id desc")
        @chaintips.uniq{ |s| s.block.block_hash }
      }
    end
  end
end
