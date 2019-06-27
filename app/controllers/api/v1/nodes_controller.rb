class Api::V1::NodesController < ApplicationController
  before_action :authenticate_user!, except: [:index_coin]
  before_action :set_node, only: [:show, :update, :destroy]

  # Unauthenticated list of nodes, per coin:
  def index_coin
    @nodes = Node.where(coin: params[:coin].upcase).order(client_type: :asc ,name: :asc, version: :desc)

    render json: @nodes
  end

  # Authenticated list of nodes, for all coins
  def index
    @nodes = Node.all
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
        render json: {errors: @node.errors}, status: :unprocessable_entity
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
    params.require(:node).permit(:name, :coin, :client_type, :rpchost, :rpcport, :rpcuser, :rpcpassword)
  end
end
