# frozen_string_literal: true

module Api
  module V1
    class LnTransactionsController < ApplicationController
      before_action :resource_class

      def index
        latest = @resource_class.last_updated_cached
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          respond_to do |format|
            format.json do
              render json: Rails.cache.fetch("api/v1/#{controller_name}.json") {
                resource_class.all_with_block_cached.to_json
              }
            end
            format.csv do
              send_data resource_class.to_csv, filename: "#{controller_name}.csv"
            end
          end
        end
      end

      private

      def resource_class
        @resource_class ||= case controller_name
                            when 'ln_penalties'
                              PenaltyTransaction
                            when 'ln_sweeps'
                              SweepTransaction
                            when 'ln_uncoops'
                              MaybeUncoopTransaction
                            end
      end
    end
  end
end
