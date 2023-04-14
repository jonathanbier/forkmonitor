# frozen_string_literal: true

module Api
  module V1
    class InvalidBlocksController < ApplicationController
      before_action :authenticate_user!, only: [:destroy]
      before_action :set_invalid_block, only: %i[show destroy]

      def admin_index
        @invalid_blocks = InvalidBlock.joins(:block)
        render json: @invalid_blocks
      end

      def index
        latest = InvalidBlock.joins(:block).order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @invalid_blocks = InvalidBlock.joins(:block).where(dismissed_at: nil)
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
