# frozen_string_literal: true

require 'webmock/rspec'

WebMock.disable_net_connect!(allow: '127.0.0.1')
