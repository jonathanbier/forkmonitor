require 'rails_helper'

RSpec.describe Api::V1::BlocksController, type: :controller do
  describe "GET /api/v1/blocks" do
    let(:user) { User.create(email: "test@example.com", password: "test1234", confirmed_at: Time.now) }
    let!(:node1) { create(:node_with_block, coin: "BTC") }

    it "should require authorization" do
      get :index, format: :json, params: {range: [0,10]}
      expect(response.status).to eq 401
    end

    describe "logged in" do
      before do
        sign_in(user)
      end

      it "should list blocks" do
        get :index, format: :json, params: {range: "[0,10]"}
        expect(response.status).to eq 200
        expect(response_body.length).to eq 1
      end

      it "should paginate blocks" do
        get :index, format: :json, params: {range: "[10,20]"}
        expect(response.status).to eq 200
        expect(response_body.length).to eq 0
      end
    end
  end

  def response_body
    JSON.parse(response.body)
  end
end
