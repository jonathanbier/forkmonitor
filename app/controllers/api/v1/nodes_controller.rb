class Api::V1::NodesController < ApplicationController
  before_action :set_node, only: [:show, :update, :destroy]
  protect_from_forgery unless: -> { request.format.json? }

  def index
    if params[:coin] && ["BTC", "BCH"].include?(params[:coin].upcase)
      @nodes = Node.where(coin: params[:coin].upcase)
    else
      @nodes = Node.all
      response.headers['X-Total-Count'] = @nodes.count
      response.headers['Access-Control-Expose-Headers'] = 'X-Total-Count'
    end
    # TODO: authenticate before adding extra fields
    if params[:coin] && ["BTC", "BCH"].include?(params[:coin].upcase)
      render json: @nodes
    else
      render json: @nodes.reorder(id: :asc).as_json(admin: true)
    end
  end

  # TODO authenticate
  def show
    render json: @node.as_json(admin: true)
  end

  # TODO authenticate
  def create
      @node = Node.new(node_params)

      @node.poll!

      if @node.save
        render json: @node, status: :created
      else
        render json: {errors: @node.errors}, status: :unprocessable_entity
      end
    end

  # TODO authenticate
  def update
    if @node.update(node_params)
      render json: @node.as_json(admin: true)
    else
      render json: @node.errors, status: :unprocessable_entity
    end
  end

  # TODO authenticate
  def destroy
    @node.destroy
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
    params.require(:node).permit(:name, :coin, :rpchost, :rpcuser, :rpcpassword, :common_height)
  end
end
