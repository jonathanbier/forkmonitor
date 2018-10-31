class Api::V1::NodesController < ApplicationController
  def index
    render json: Node.order(pos: :asc).all
  end
end
