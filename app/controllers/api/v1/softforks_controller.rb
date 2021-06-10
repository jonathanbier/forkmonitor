# frozen_string_literal: true

module Api
  module V1
    class SoftforksController < ApplicationController
      before_action :set_coin

      def index
        render json: Softfork.where(coin: @coin)
      end
    end
  end
end
