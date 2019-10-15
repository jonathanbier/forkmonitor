require 'rails_helper'

RSpec.describe InflatedBlock, type: :model do
  describe "Block.check_inflation!" do
    before do
      @node = build(:node_with_mirror, version: 170001)
      @node.client.mock_set_height(560176)
      @node.mirror_client.mock_set_height(560176)
      @node.poll!
      @node.reload
      
      @node_without_mirror = build(:node, version: 180000)

      @node_testnet = build(:node_with_mirror, version: 180000, coin: "TBTC")
      @node_testnet.client.mock_set_height(560176)
      @node_testnet.mirror_client.mock_set_height(560176)
      @node_testnet.poll!
      @node_testnet.reload
      
      expect(Block.maximum(:height)).to eq(560176)
      allow(Node).to receive(:where).with(coin: "BTC").and_return [@node_without_mirror, @node]
      allow(Node).to receive(:where).with(coin: "TBTC").and_return [@node_testnet]
    end
    
    it "should stop p2p networking and restart it after" do
      expect(@node.mirror_client).to receive("setnetworkactive").with(false)
      expect(@node.mirror_client).to receive("setnetworkactive").with(true)
      Block.check_inflation!(:btc)
    end

    it "should call gettxoutsetinfo on BTC mirror node" do
      expect(@node.mirror_client).to receive("gettxoutsetinfo").and_call_original

      Block.check_inflation!(:btc)

      expect(TxOutset.count).to eq(1)
      expect(TxOutset.first.block.height).to eq(560176)
    end
    
    it "should call gettxoutsetinfo testnet on mirror node" do
      expect(@node_testnet.mirror_client).to receive("gettxoutsetinfo").and_call_original

      Block.check_inflation!(:tbtc)

      expect(TxOutset.count).to eq(1)
      expect(TxOutset.first.block.height).to eq(560176)
    end

    it "should not call gettxoutsetinfo for block with tx info" do
      Block.check_inflation!(:btc)
      expect(@node.mirror_client).not_to receive("gettxoutsetinfo").and_call_original
      Block.check_inflation!(:btc)
    end

    it "should not create duplicate TxOutset entries" do
      Block.check_inflation!(:btc)
      Block.check_inflation!(:btc)
      expect(TxOutset.count).to eq(1)
    end

    describe "BTC mirror node has three more blocks" do
      before do
        Block.check_inflation!(:btc)
        @node.mirror_client.mock_set_height(560179)
      end

      it "should fetch intermediate BTC blocks" do
        Block.check_inflation!(:btc)
        expect(Block.maximum(:height)).to eq(560179)
        expect(Block.find_by(height: 560178)).not_to be_nil
        expect(Block.find_by(height: 560177)).not_to be_nil
      end
      
      it "should invalidate the second block, and later the third block to wind back the tip" do
        expect(@node.mirror_client).to receive("invalidateblock").with("00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9").ordered.and_call_original
        expect(@node.mirror_client).to receive("reconsiderblock").with("00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9").ordered.and_call_original
        expect(@node.mirror_client).to receive("invalidateblock").with("000000000000000000017b592e9ecd6ce8ab9b5a2f391e21ee2e80b022a7dafc").ordered.and_call_original
        expect(@node.mirror_client).to receive("reconsiderblock").with("000000000000000000017b592e9ecd6ce8ab9b5a2f391e21ee2e80b022a7dafc").ordered.and_call_original
        Block.check_inflation!(:btc)
      end

      it "should create three new TxOutset entries" do
        Block.check_inflation!(:btc)
        expect(TxOutset.count).to eq(4)
        expect(TxOutset.fourth.total_amount - TxOutset.third.total_amount).to eq(12.5)
        expect(TxOutset.third.total_amount - TxOutset.second.total_amount).to eq(12.5)
        expect(TxOutset.second.total_amount - TxOutset.first.total_amount).to eq(12.5)
      end

    end

    describe "with extra inflation" do
      let(:user) { create(:user) }

      before do
        Block.check_inflation!(:btc)
        @node.mirror_client.mock_set_height(560178)
        @node.mirror_client.mock_set_extra_inflation(1)
      end

      it "should add a InflatedBlock entry" do
        begin
          Block.check_inflation!(:btc)
        rescue UncaughtThrowError
          # Ignore error
        end
        expect(InflatedBlock.count).to eq(1)
      end
      
      it "should mark txoutset as inflated" do
        begin
          Block.check_inflation!(:btc)
        rescue UncaughtThrowError
          # Ignore error
        end
        tx_outset = InflatedBlock.first.tx_outset
        expect(InflatedBlock.first.tx_outset.inflated).to eq(true)
      end
      
      it "should add a InflatedBlock entry for testnet inflation" do
        @node_testnet.mirror_client.mock_set_extra_inflation(1)
        begin
          Block.check_inflation!(:btc)
        rescue UncaughtThrowError
          # Ignore error
        end
        expect(InflatedBlock.count).to eq(1)
      end

      it "should send an alert" do
        expect(User).to receive(:all).and_return [user]
        expect {  Block.check_inflation!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "should send email only once" do
        expect(User).to receive(:all).and_return [user]
        expect {  Block.check_inflation!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect {  Block.check_inflation!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(0)
      end

    end

  end
end
