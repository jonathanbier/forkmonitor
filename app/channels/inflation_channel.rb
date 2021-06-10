# frozen_string_literal: true

class InflationChannel < ApplicationCable::Channel # rubocop:todo Style/Documentation
  def subscribed
    @node = Node.find(params[:node])
    stream_for @node # "inflation_node_#{ @node }"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
