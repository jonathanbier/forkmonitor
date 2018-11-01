require 'rails_helper'

describe BitcoinClient do
  describe "instance" do
    before do
      @client = described_class.new("BTC", "127.0.0.1", "user", "password", "Bitcoin Core", 1)
    end

    describe "help" do
      it "should help rpc method" do
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
        expect(@client).to receive(:request).with("getblock", "hash")
        @client.getblock("hash")
      end
    end
  end
end
