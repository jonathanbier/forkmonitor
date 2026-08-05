# frozen_string_literal: true

require 'rails_helper'

describe BoundedBitcoinerClient do
  subject(:client) { described_class.new('user', 'password', '127.0.0.1:8332') }

  let(:response) do
    instance_double(
      Typhoeus::Response,
      success?: true,
      body: '{"result":{"blocks":1},"error":null,"id":"jsonrpc"}'
    )
  end

  it 'passes total and connection timeouts to libcurl' do
    expect(Typhoeus).to receive(:post).with(
      client.endpoint,
      hash_including(timeout: 120, connecttimeout: 30)
    ).and_return(response)

    expect(client.request('getblockchaininfo', timeout: 120)).to eq('blocks' => 1)
  end

  it 'bounds connection setup when an RPC has no total timeout' do
    expect(Typhoeus).to receive(:post).with(
      client.endpoint,
      hash_including(connecttimeout: 30)
    ) do |_endpoint, options|
      expect(options).not_to have_key(:timeout)
      response
    end

    client.request('gettxoutsetinfo')
  end
end
