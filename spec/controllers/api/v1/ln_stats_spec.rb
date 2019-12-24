require 'rails_helper'

RSpec.describe Api::V1::LnStatsController, type: :controller do
  let!(:ln_penalty) { create(:penalty_transaction_public) }

  describe "GET /api/v1/ln_stats" do

    before do
      get :index, format: :json
      expect(response.status).to eq 200
    end

    it "should show count" do
      expect(response_body["count"]).to eq 1
    end

    it "should show total" do
      expect(response_body["total"]).to eq "1.33874639"
    end

  end

  def response_body
    JSON.parse(response.body)
  end
end
