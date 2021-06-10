# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::LnStatsController, type: :controller do
  let(:block1) { create(:lightning_block) }
  let!(:ln_penalty) { create(:penalty_transaction_public, block: block1) }
  let!(:ln_sweep) { create(:sweep_transaction_public, block: block1) }

  describe 'GET /api/v1/ln_stats' do
    before do
      get :index, format: :json
      expect(response.status).to eq 200
    end

    it 'should show penalty count' do
      expect(response_body['penalty_count']).to eq 1
    end

    it 'should show penalty total' do
      expect(response_body['penalty_total']).to eq '1.33874639'
    end

    it 'should show sweep count' do
      expect(response_body['sweep_count']).to eq 1
    end

    it 'should show sweep total' do
      expect(response_body['sweep_total']).to eq '0.00018969'
    end
  end

  def response_body
    JSON.parse(response.body)
  end
end
