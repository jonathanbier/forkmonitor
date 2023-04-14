# frozen_string_literal: true

module Api
  module V1
    class SoftforksController < ApplicationController
      def index
        render json: Softfork.all
      end
    end
  end
end
