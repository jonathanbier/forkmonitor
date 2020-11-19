class Api::V1::StaleCandidatesController < ApplicationController
  before_action :set_coin
  before_action :set_stale_candidate, except: [:info]

  def index
    render json: StaleCandidate.index_json_cached(@coin)
  end

  def show
    render json: @stale_candidate.json_cached
  end

  def double_spend_info
    render json: @stale_candidate.double_spend_info_cached
  end

  private

  def set_stale_candidate
    @stale_candidate = StaleCandidate.find_by!(coin: @coin, height: params[:height])
  end
end
