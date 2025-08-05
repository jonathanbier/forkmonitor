# frozen_string_literal: true

module Api
  module V1
    class SubscriptionsController < ApplicationController
      def create
        Subscription.find_or_create_by(endpoint: subscription_params['endpoint']) do |subscription|
          subscription.p256dh = subscription_params['keys']['p256dh']
          subscription.auth = subscription_params['keys']['auth']
        end

        render json: {}, status: :created
      end

      private

      def subscription_params
        return {} unless params[:subscription].is_a? ActionController::Parameters

        params.fetch(:subscription, {}).permit(:endpoint, :expirationTime, keys: %i[p256dh auth])
      end
    end
  end
end
