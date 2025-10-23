# frozen_string_literal: true

require 'rails_helper'

describe BitcoinClient do
  around do |example|
    previous = Thread.report_on_exception
    Thread.report_on_exception = false
    example.run
  ensure
    Thread.report_on_exception = previous
  end

  describe 'instance' do
    before do
      @client = described_class.new(1, 'Bitcoin Core v0.19.0', :core, 190_000, '127.0.0.1', '8332', 'user',
                                    'password')
    end

    describe 'help' do
      it 'calls help rpc method' do
        expect(@client).to receive(:request).with('help')
        @client.help
      end
    end

    describe 'getnetworkinfo' do
      it 'tries getnetworkinfo rpc first' do
        expect(@client).to receive(:request).with('getnetworkinfo')
        @client.getnetworkinfo
      end
    end

    describe 'getblockchaininfo' do
      it 'getblockchaininfoes rpc method' do
        expect(@client).to receive(:request).with('getblockchaininfo')
        @client.getblockchaininfo
      end
    end

    describe 'getbestblockhash' do
      it 'getbestblockhashes rpc method' do
        expect(@client).to receive(:request).with('getbestblockhash')
        @client.getbestblockhash
      end
    end

    describe 'getblock' do
      it 'getblocks rpc method with hash' do
        expect(@client).to receive(:request).with('getblock', 'hash', 1)
        @client.getblock('hash', 1)
      end

      it 'catches connection error' do
        expect(@client.client).to receive(:request).and_raise(Bitcoiner::Client::JSONRPCError, 'couldnt_connect')
        expect { @client.getblock('hash', 1) }.to raise_error(BitcoinUtil::RPC::ConnectionError)
      end

      it 'catches partial file error' do
        expect(@client).to receive(:request).and_raise(Bitcoiner::Client::JSONRPCError, 'partial_file')
        expect { @client.getblock('hash', 1) }.to raise_error(BitcoinUtil::RPC::PartialFileError)
      end
    end

    describe 'getblockheader' do
      it 'getblockheaders rpc method with hash' do
        expect(@client).to receive(:request).with('getblockheader', 'hash', true)
        @client.getblockheader('hash')
      end
    end

    describe 'getmempoolinfo' do
      it 'calls getmempoolinfo rpc method' do
        expect(@client).to receive(:request).with('getmempoolinfo')
        @client.getmempoolinfo
      end
    end

    describe 'gettxoutsetinfo' do
      it 'calls gettxoutsetinfo rpc method' do
        expect(@client).to receive(:request).with('gettxoutsetinfo')
        @client.gettxoutsetinfo
      end
    end

    describe 'setnetworkactive' do
      it 'calls setnetworkactive rpc method' do
        expect(@client).to receive(:request).with('setnetworkactive', true)
        @client.setnetworkactive(true)
      end
    end

    describe 'invalidateblock' do
      it 'calls invalidateblock rpc method' do
        block_hash = '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377'
        expect(@client).to receive(:request).with('invalidateblock', block_hash)
        @client.invalidateblock(block_hash)
      end
    end

    describe 'reconsiderblock' do
      it 'calls reconsiderblock rpc method' do
        block_hash = '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377'
        expect(@client).to receive(:request).with('reconsiderblock', block_hash)
        @client.reconsiderblock(block_hash)
      end

      it 'ignores (block not found) error' do
        block_hash = '0000000000000000000000000000000000000000000000000000000000000000'
        expect(@client).to receive(:request).with('reconsiderblock', block_hash).and_raise(
          Bitcoiner::Client::JSONRPCError, 'ok'
        )
        @client.reconsiderblock(block_hash)
      end
    end
  end
end
