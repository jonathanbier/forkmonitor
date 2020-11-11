require 'rails_helper'

RSpec.describe Api::V1::NodesController, type: :controller do
  describe "GET /api/v1/nodes/btc" do
    let!(:node1) { create(:node_with_block, coin: :btc) }
    let!(:node2) { create(:node_with_block, coin: :btc) }

    it "should list nodes" do
      get :index_coin, format: :json, params: {coin: "BTC"}
      expect(response.status).to eq 200
      expect(response_body.length).to eq 2
    end
  end

  def response_body
    JSON.parse(response.body)
  end
end
