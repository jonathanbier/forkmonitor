# frozen_string_literal: true

module Api
  module V1
    class NodesController < ApplicationController
      before_action :authenticate_user!, except: [:index_coin]
      before_action :set_node, only: %i[show update destroy]
      before_action :set_coin, only: :index_coin

      # Unauthenticated list of nodes, per coin:
      def index_coin
        latest = Node.last_updated_cached(@coin.upcase)
        if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
          @nodes = Node.where(enabled: true, coin: @coin).order(client_type: :asc, name: :asc, version: :desc)
          render json: @nodes
        end
      end

      # Authenticated list of nodes, for all coins
      def index
        @nodes = Node.where(to_destroy: false)
        response.headers['Content-Range'] = @nodes.count
        render json: @nodes.reorder(id: :asc).as_json(admin: true)
      end

      def show
        render json: @node.as_json(admin: true)
      end

      def create
        @node = Node.new(node_params)

        @node.poll!

        if @node.save
          render json: @node, status: :created
        else
          render json: { errors: @node.errors }, status: :unprocessable_entity
        end
      end

      def update
        if @node.update(node_params)
          render json: @node.as_json(admin: true)
        else
          render json: @node.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @node.update enabled: false, to_destroy: true
        head :no_content
      end

      def delete
        destroy
      end

      private

      def set_node
        @node = Node.find(params[:id])
      end

      def node_params
        params.require(:node).permit(:name, :coin, :client_type, :version_extra, :rpchost, :mirror_rpchost, :rpcport,
                                     :mirror_rpcport, :rpcuser, :rpcpassword, :pruned, :txindex, :os, :cpu, :ram, :storage, :cve_2018_17144, :released, :enabled, :link, :link_text, :getblocktemplate, :to_destroy)
      end
    end
  end
end
