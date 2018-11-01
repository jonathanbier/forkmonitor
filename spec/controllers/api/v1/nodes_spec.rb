require 'rails_helper'

RSpec.describe Api::V1::NodesController, type: :controller do
  describe "GET /api/v1/nodes" do
    let!(:node1) { create(:node) }
    let!(:node2) { create(:node) }

    it "should list nodes" do
      get :index, format: :json
      expect(response.status).to eq 200
      expect(response_body.length).to eq 2
    end
  end

  def response_body
    JSON.parse(response.body)
  end
end
