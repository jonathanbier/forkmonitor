# frozen_string_literal: true

module Api
  module V1
    class LnStatsController < ApplicationController
      def index
        latest = LightningTransaction.order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @ln_stats = {
            penalty_count: PenaltyTransaction.count,
            penalty_total: PenaltyTransaction.sum(:amount),
            sweep_count: SweepTransaction.count,
            sweep_total: SweepTransaction.sum(:amount)
          }
          render json: @ln_stats
        end
      end
    end
  end
end
