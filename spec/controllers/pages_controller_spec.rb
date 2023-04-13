# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PagesController do
  describe 'GET /' do
    it 'loads' do
      get :root
      expect(response).to have_http_status :ok
    end
  end
end
