# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::LnStatsController do
  let(:block_1) { create(:lightning_block) }

  before do
    create(:penalty_transaction_public, block: block_1)
    create(:sweep_transaction_public, block: block_1)
  end

  describe 'GET /api/v1/ln_stats' do
    before do
      get :index, format: :json
      expect(response).to have_http_status :ok
    end

    it 'shows penalty count' do
      expect(response_body['penalty_count']).to eq 1
    end

    it 'shows penalty total' do
      expect(response_body['penalty_total']).to eq '1.33874639'
    end

    it 'shows sweep count' do
      expect(response_body['sweep_count']).to eq 1
    end

    it 'shows sweep total' do
      expect(response_body['sweep_total']).to eq '0.00018969'
    end
  end

  def response_body
    JSON.parse(response.body)
  end
end
