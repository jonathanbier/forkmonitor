# frozen_string_literal: true

module Api
  module V1
    class InflatedBlocksController < ApplicationController
      before_action :authenticate_user!, only: [:destroy]
      before_action :set_inflated_block, only: %i[show destroy]
      before_action :set_coin_optional

      def index
        if @coin.present?
          latest = InflatedBlock.joins(:block).where('blocks.coin = ?',
                                                     Block.coins[@coin]).order(updated_at: :desc).first
          if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
            @inflated_blocks = InflatedBlock.joins(:block).where(dismissed_at: nil).where('blocks.coin = ?',
                                                                                          Block.coins[@coin])
            response.headers['Content-Range'] = @inflated_blocks.count
            render json: @inflated_blocks
          end
        else
          @inflated_blocks = InflatedBlock.all
          response.headers['Content-Range'] = @inflated_blocks.count
          render json: @inflated_blocks
        end
      end

      def show
        render json: @inflated_block
      end

      # Mark as dismissed
      def destroy
        @inflated_block.update dismissed_at: Time.now
        head :no_content
      end

      private

      def set_inflated_block
        @inflated_block = InflatedBlock.find(params[:id])
      end

      def inflated_block_params
        params.require(:inflated_block)
      end
    end
  end
end
