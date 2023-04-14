# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::BlocksController do
  describe 'GET /api/v1/blocks' do
    before do
      create(:node_with_block)
    end

    it 'lists blocks' do
      get :index, format: :json, params: { range: '[0,10]' }
      expect(response).to have_http_status :ok
      expect(response_body.length).to eq 1
    end

    it 'paginates blocks' do
      get :index, format: :json, params: { range: '[10,20]' }
      expect(response).to have_http_status :ok
      expect(response_body.length).to eq 0
    end
  end

  def response_body
    JSON.parse(response.body)
  end
end
