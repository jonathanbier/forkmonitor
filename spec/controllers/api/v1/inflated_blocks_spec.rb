# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::InflatedBlocksController, type: :controller do
  let!(:node1) { create(:node_with_block, coin: :btc) }
  let!(:inflated_block) { create(:inflated_block, node: node1) }

  describe 'GET /api/v1/inflated_blocks' do
    it 'should list inflated blocks' do
      get :index, format: :json
      expect(response.status).to eq 200
      expect(response_body.length).to eq 1
    end

    it 'should list dismissed entries' do
      inflated_block.update dismissed_at: Time.now
      get :index, format: :json
      expect(response.status).to eq 200
      expect(response_body.length).to eq 1
    end

    describe 'with coin param' do
      it 'should list entries for this coin' do
        get :index, format: :json, params: { coin: 'BTC' }
        expect(response.status).to eq 200
        expect(response_body.length).to eq 1
      end

      it 'should not list entries for other coin' do
        get :index, format: :json, params: { coin: 'TBTC' }
        expect(response.status).to eq 200
        expect(response_body.length).to eq 0
      end

      it 'should not list dismissed entries' do
        inflated_block.update dismissed_at: Time.now
        get :index, format: :json, params: { coin: 'BTC' }
        expect(response.status).to eq 200
        expect(response_body.length).to eq 0
      end
    end
  end

  describe 'DELETE /api/v1/inflated_blocks/:id' do
    it 'should require authorization' do
      delete :destroy, params: { id: inflated_block.id }
      expect(response.status).to eq 401
    end

    describe 'admin' do
      let(:admin) { User.create(email: 'test@example.com', password: 'test1234', confirmed_at: Time.now) }

      before do
        sign_in(admin)
      end

      it 'can mark as dismissed by deleting' do
        delete :destroy, params: { id: inflated_block.id }
        expect(response.status).to eq 204
        inflated_block.reload
        expect(inflated_block.dismissed_at).not_to be_nil
      end
    end
  end

  def response_body
    JSON.parse(response.body)
  end
end
