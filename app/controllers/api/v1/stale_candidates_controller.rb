class Api::V1::StaleCandidatesController < ApplicationController
  before_action :set_coin
  before_action :set_stale_candidate, only: [:show]

  def index
    render json: StaleCandidate.where(coin: @coin).order(height: :desc).limit(10)
  end

  def show
    render json: @stale_candidate
  end

  private

  def set_stale_candidate
    @stale_candidate = StaleCandidate.find_by!(coin: @coin, height: params[:height])
  end
end
