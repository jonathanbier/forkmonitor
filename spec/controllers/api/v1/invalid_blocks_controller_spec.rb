# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::InvalidBlocksController, type: :controller do
  let!(:node_1) { create(:node_with_block, coin: :btc) }
  let!(:invalid_block) { create(:invalid_block, node: node_1) }

  describe 'GET /api/v1/invalid_blocks' do
    it 'lists invalid blocks' do
      get :index, format: :json
      expect(response).to have_http_status :ok
      expect(response_body.length).to eq 1
    end

    it 'lists dismissed entries' do
      invalid_block.update dismissed_at: Time.zone.now
      get :index, format: :json
      expect(response).to have_http_status :ok
      expect(response_body.length).to eq 1
    end

    describe 'with coin param' do
      it 'lists entries for this coin' do
        get :index, format: :json, params: { coin: :btc }
        expect(response).to have_http_status :ok
        expect(response_body.length).to eq 1
      end

      it 'does not list entries for other coin' do
        get :index, format: :json, params: { coin: :tbtc }
        expect(response).to have_http_status :ok
        expect(response_body.length).to eq 0
      end

      it 'does not list dismissed entries' do
        invalid_block.update dismissed_at: Time.zone.now
        get :index, format: :json, params: { coin: :btc }
        expect(response).to have_http_status :ok
        expect(response_body.length).to eq 0
      end
    end
  end

  describe 'DELETE /api/v1/invalid_blocks/:id' do
    it 'requires authorization' do
      delete :destroy, params: { id: invalid_block.id }
      expect(response).to have_http_status :unauthorized
    end

    describe 'admin' do
      let(:admin) { User.create(email: 'test@example.com', password: 'test1234', confirmed_at: Time.zone.now) }

      before do
        sign_in(admin)
      end

      it 'can mark as dismissed by deleting' do
        delete :destroy, params: { id: invalid_block.id }
        expect(response).to have_http_status :no_content
        invalid_block.reload
        expect(invalid_block.dismissed_at).not_to be_nil
      end
    end
  end

  def response_body
    JSON.parse(response.body)
  end
end
