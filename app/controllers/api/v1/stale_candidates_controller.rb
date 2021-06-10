# frozen_string_literal: true

module Api
  module V1
    class StaleCandidatesController < ApplicationController
      before_action :set_coin
      before_action :set_stale_candidate, except: [:index]

      def index
        render json: StaleCandidate.index_json_cached(@coin)
      end

      def show
        info = @stale_candidate.json_cached
        if info.present?
          render json: info
        else
          response.headers['Retry-After'] = '5'
          render json: '', status: :service_unavailable
        end
      end

      def double_spend_info
        info = @stale_candidate.double_spend_info_cached
        if info.present?
          render json: info
        else
          response.headers['Retry-After'] = '5'
          render json: '', status: :service_unavailable
        end
      end

      private

      def set_stale_candidate
        @stale_candidate = StaleCandidate.find_by!(coin: @coin, height: params[:height])
      end
    end
  end
end
