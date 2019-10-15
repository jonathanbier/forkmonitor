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

    describe "BTC mirror node has two more blocks" do
      before do
        Block.check_inflation!(:btc)

        @node.mirror_client.mock_set_height(560178)
      end

      it "should fetch intermediate BTC blocks" do
        Block.check_inflation!(:btc)
        expect(Block.maximum(:height)).to eq(560178)
        expect(TxOutset.count).to eq(2)
        expect(TxOutset.last.block.height).to eq(560178)
      end

      describe "with normal inflation" do
        before do
          Block.check_inflation!(:btc)
        end

        it "mock UTXO set should have increase by be 2 x 12.5 BTC" do
          expect(TxOutset.last.total_amount - TxOutset.first.total_amount).to eq(25.0)
        end

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
