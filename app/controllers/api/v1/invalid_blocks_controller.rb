# frozen_string_literal: true

module Api
  module V1
    class InvalidBlocksController < ApplicationController
      before_action :authenticate_user!, only: [:destroy]
      before_action :set_invalid_block, only: %i[show destroy]
      before_action :set_coin_optional

      def index
        if @coin.present?
          latest = InvalidBlock.joins(:block).where('blocks.coin = ?',
                                                    Block.coins[@coin]).order(updated_at: :desc).first
          if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
            @invalid_blocks = InvalidBlock.joins(:block).where(dismissed_at: nil).where('blocks.coin = ?',
                                                                                        Block.coins[@coin])
            response.headers['Content-Range'] = @invalid_blocks.count
            render json: @invalid_blocks
          end
        else
          @invalid_blocks = InvalidBlock.all
          response.headers['Content-Range'] = @invalid_blocks.count
          render json: @invalid_blocks
        end
      end

      def show
        render json: @invalid_block
      end

      # Mark as dismissed
      def destroy
        @invalid_block.update dismissed_at: Time.zone.now
        head :no_content
      end

      private

      def set_invalid_block
        @invalid_block = InvalidBlock.find(params[:id])
      end

      def invalid_block_params
        params.require(:invalid_block)
      end
    end
  end
end
