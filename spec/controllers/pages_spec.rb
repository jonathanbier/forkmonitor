# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PagesController, type: :controller do
  describe 'GET /' do
    it 'should load' do
      get :root
      expect(response.status).to eq 200
    end
  end
end
