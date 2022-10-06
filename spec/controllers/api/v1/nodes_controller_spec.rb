# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::NodesController, type: :controller do
  describe 'GET /api/v1/nodes/btc' do
    before do
      create(:node_with_block, coin: :btc)
      create(:node_with_block, coin: :btc)
    end

    it 'lists nodes' do
      get :index_coin, format: :json, params: { coin: 'BTC' }
      expect(response).to have_http_status :ok
      expect(response_body.length).to eq 2
    end
  end

  def response_body
    JSON.parse(response.body)
  end
end
