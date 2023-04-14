# frozen_string_literal: true

module Api
  module V1
    class BlocksController < ApplicationController
      before_action :authenticate_user!, only: :show

      # List of blocks
      def index
        respond_to do |format|
          format.json do
            @range = JSON.parse(params['range'])
            @offset = @range[0]
            @limit = @range[1]
            @blocks = Block.order(height: :desc).offset(@offset).limit(@limit)
            response.headers['Content-Range'] = Block.count
            render json: @blocks
          end
          format.csv do
            @start = params[:start] || 0
            @blocks = Block.where('height >= ?', @start).order(height: :asc)
            send_data @blocks.to_csv, filename: "#{controller_name}.csv"
          end
        end
      end

      def show
        render json: @block
      end

      def with_hash
        @block = Block.find_by!(block_hash: params['block_hash'])
        render json: @block.as_json(tx_diff: true)
      end

      def max_height
        @max_height = Block.maximum(:height)
        render json: @max_height
      end
    end
  end
end
