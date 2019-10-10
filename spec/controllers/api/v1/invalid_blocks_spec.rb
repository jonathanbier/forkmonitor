require 'rails_helper'

RSpec.describe Api::V1::InvalidBlocksController, type: :controller do
  describe "GET /api/v1/invalid_blocks" do
    let!(:node1) { create(:node_with_block, coin: "BTC") }
    let!(:invalid_block) { create(:invalid_block, node: node1) }

    it "should list invalid blocks" do
      get :index, format: :json
      expect(response.status).to eq 200
      expect(response_body.length).to eq 1
    end
    
    it "should list dismissed entries" do
      invalid_block.update dismissed_at: Time.now
      get :index, format: :json
      expect(response.status).to eq 200
      expect(response_body.length).to eq 1
    end
    
    describe "with coin param" do
      it "should list entries for this coin" do
        get :index, format: :json, params: {coin: "BTC"}
        expect(response.status).to eq 200
        expect(response_body.length).to eq 1
      end
      
      it "should not list entries for other coin" do
        get :index, format: :json, params: {coin: "TBTC"}
        expect(response.status).to eq 200
        expect(response_body.length).to eq 0
      end
      
      it "should not list dismissed entries" do
        invalid_block.update dismissed_at: Time.now
        get :index, format: :json, params: {coin: "BTC"}
        expect(response.status).to eq 200
        expect(response_body.length).to eq 0
      end
    end

  end

  def response_body
    JSON.parse(response.body)
  end
end
