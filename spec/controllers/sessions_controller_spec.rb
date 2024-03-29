# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionsController do
  describe 'POST /login', type: :request do
    let(:user) { User.create(email: 'test@example.com', password: 'test1234', confirmed_at: Time.zone.now) }
    let(:url) { '/login' }
    let(:params) do
      {
        user: {
          email: user.email,
          password: user.password
        }
      }
    end

    context 'when params are correct' do
      before do
        post url, params: params
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JTW token in authorization header' do
        expect(response.headers['Authorization']).to be_present
      end

      it 'returns valid JWT token' do
        token_from_request = response.headers['Authorization'].split.last
        decoded_token = JWT.decode(token_from_request, ENV.fetch('DEVISE_JWT_SECRET_KEY', nil), true)
        expect(decoded_token.first['sub']).to be_present
      end
    end

    context 'when login params are incorrect' do
      before { post url }

      it 'returns unathorized status' do
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe 'DELETE /logout', type: :request do
    let(:url) { '/logout' }

    it 'returns 204, no content' do
      delete url
      expect(response).to have_http_status(:no_content)
    end
  end
end
