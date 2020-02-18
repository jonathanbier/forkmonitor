require 'rails_helper'

describe BitcoinClient do

  describe "instance" do
    before do
      @client = described_class.new(1, "Bitcoin Core v0.19.0", :core, "127.0.0.1", "8332", "user", "password")
    end

    describe "help" do
      it "should call help rpc method" do
        expect(@client).to receive(:request).with("help")
        @client.help
      end
    end

    describe "getnetworkinfo" do
      it "should try getnetworkinfo rpc first" do
        expect(@client).to receive(:request).with("getnetworkinfo")
        @client.getnetworkinfo
      end
    end

    describe "getblockchaininfo" do
      it "should getblockchaininfo rpc method" do
        expect(@client).to receive(:request).with("getblockchaininfo")
        @client.getblockchaininfo
      end
    end

    describe "getbestblockhash" do
      it "should getbestblockhash rpc method" do
        expect(@client).to receive(:request).with("getbestblockhash")
        @client.getbestblockhash
      end
    end

    describe "getblock" do
      it "should getblock rpc method with hash" do
        expect(@client).to receive(:request).with("getblock", "hash", 1)
        @client.getblock("hash", 1)
      end
    end

    describe "getblockheader" do
      it "should getblockheader rpc method with hash" do
        expect(@client).to receive(:request).with("getblockheader", "hash")
        @client.getblockheader("hash")
      end
    end

    describe "gettxoutsetinfo" do
      it "should call gettxoutsetinfo rpc method" do
        expect(@client).to receive(:request).with("gettxoutsetinfo")
        @client.gettxoutsetinfo
      end
    end

    describe "setnetworkactive" do
      it "should call setnetworkactive rpc method" do
        expect(@client).to receive(:request).with("setnetworkactive", true)
        @client.setnetworkactive(true)
      end
    end

    describe "invalidateblock" do
      it "should call invalidateblock rpc method" do
        block_hash = "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377"
        expect(@client).to receive(:request).with("invalidateblock", block_hash)
        @client.invalidateblock(block_hash)
      end
    end

    describe "reconsiderblock" do
      it "should call reconsiderblock rpc method" do
        block_hash = "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377"
        expect(@client).to receive(:request).with("reconsiderblock", block_hash)
        @client.reconsiderblock(block_hash)
      end

      it "should ignore (block not found) error" do
        block_hash = "0000000000000000000000000000000000000000000000000000000000000000"
        expect(@client).to receive(:request).with("reconsiderblock", block_hash).and_raise(Bitcoiner::Client::JSONRPCError, "ok")
        @client.reconsiderblock(block_hash)
      end
    end
  end
end
