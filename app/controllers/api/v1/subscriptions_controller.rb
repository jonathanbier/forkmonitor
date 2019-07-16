class Api::V1::SubscriptionsController < ApplicationController

  def create
    Subscription.find_or_create_by(endpoint: subscription_params["endpoint"]) do |subscription|
      subscription.p256dh = subscription_params["keys"]["p256dh"]
      subscription.auth = subscription_params["keys"]["auth"]
    end

    render json: {}, status: :created
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, :expirationTime, :keys => [:p256dh, :auth])
  end
end
