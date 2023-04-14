# frozen_string_literal: true

module Api
  module V1
    class ChaintipsController < ApplicationController
      def index
        latest = Chaintip.order(updated_at: :desc).first
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          render json: Rails.cache.fetch('Chaintip.index.json') {
            @chaintips = Chaintip.where(status: 'active', parent_chaintip: nil).includes(:block, :node).order('blocks.work desc, nodes.client_type asc, nodes.name asc, nodes.version desc')
            @chaintips.uniq { |s| s.block.block_hash }
          }
        end
      end
    end
  end
end
