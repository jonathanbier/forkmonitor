require 'rails_helper'

RSpec.describe InflatedBlock, type: :model do
  describe "InflatedBlock.check_inflation!" do
    before do
      @node = build(:node_with_mirror, version: 170001)
      @node.client.mock_set_height(560176)
      @node.mirror_client.mock_set_height(560176)
      @node.poll!
      @node.poll_mirror!
      @node.reload

      @node_without_mirror = build(:node, version: 180000)

      @node_testnet = build(:node_with_mirror, version: 180000, coin: "TBTC")
      @node_testnet.client.mock_set_height(560176)
      @node_testnet.mirror_client.mock_set_height(560176)
      @node_testnet.poll!
      @node_testnet.reload

      expect(Block.maximum(:height)).to eq(560176)
      allow(Node).to receive(:coin_by_version).with(:btc).and_return [@node_without_mirror, @node]
      allow(Node).to receive(:coin_by_version).with(:tbtc).and_return [@node_testnet]

      # throw the first time for lacking a comparison block
      expect { InflatedBlock.check_inflation!({coin: :btc, max: 0}) }.to raise_error("More than 0 blocks behind for inflation check, please manually check 560176 (0000000000000000000b1e380c92ea32288b0106ef3ed820db3b374194b15aab) and earlier")
      expect(TxOutset.count).to eq(1)
      @node.mirror_client.mock_set_height(560177)

      expect { InflatedBlock.check_inflation!({coin: :tbtc, max: 0}) }.to raise_error("More than 0 blocks behind for inflation check, please manually check 560176 (0000000000000000000b1e380c92ea32288b0106ef3ed820db3b374194b15aab) and earlier")
      expect(TxOutset.count).to eq(2)
      @node_testnet.mirror_client.mock_set_height(560177)
    end

    it "should stop p2p networking and restart it after" do
      expect(@node.mirror_client).to receive("setnetworkactive").with(true) # restore
      expect(@node.mirror_client).to receive("setnetworkactive").with(false)
      expect(@node.mirror_client).to receive("setnetworkactive").with(true)

      InflatedBlock.check_inflation!({coin: :btc, max: 1})
    end

    it "should call gettxoutsetinfo on BTC mirror node" do
      expect(@node.mirror_client).to receive("gettxoutsetinfo").and_call_original

      InflatedBlock.check_inflation!({coin: :btc})

      expect(TxOutset.count).to eq(3)
      expect(TxOutset.last.block.height).to eq(560177)
    end

    it "should call gettxoutsetinfo testnet on mirror node" do
      expect(@node_testnet.mirror_client).to receive("gettxoutsetinfo").and_call_original

      InflatedBlock.check_inflation!({coin: :tbtc})

      expect(TxOutset.count).to eq(3)
      expect(TxOutset.last.block.height).to eq(560177)
    end

    it "should not call gettxoutsetinfo for block with tx info" do
      InflatedBlock.check_inflation!({coin: :btc})
      expect(@node.mirror_client).not_to receive("gettxoutsetinfo").and_call_original
      InflatedBlock.check_inflation!({coin: :btc})
    end

    it "should not create duplicate TxOutset entries" do
      InflatedBlock.check_inflation!({coin: :btc})
      InflatedBlock.check_inflation!({coin: :btc})
      expect(TxOutset.count).to eq(3)
    end

    describe "BTC mirror node has three more blocks" do
      before do
        @node.mirror_client.mock_set_height(560179)
      end

      it "should fetch intermediate BTC blocks" do
        InflatedBlock.check_inflation!({coin: :btc})
        expect(Block.maximum(:height)).to eq(560179)
        expect(Block.find_by(height: 560178)).not_to be_nil
        expect(Block.find_by(height: 560177)).not_to be_nil
      end

      it "should invalidate the second block, and later the third block to wind back the tip" do
        expect(@node.mirror_client).to receive("invalidateblock").with("00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9").ordered.and_call_original
        expect(@node.mirror_client).to receive("reconsiderblock").with("00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9").ordered.and_call_original
        expect(@node.mirror_client).to receive("invalidateblock").with("000000000000000000017b592e9ecd6ce8ab9b5a2f391e21ee2e80b022a7dafc").ordered.and_call_original
        expect(@node.mirror_client).to receive("reconsiderblock").with("000000000000000000017b592e9ecd6ce8ab9b5a2f391e21ee2e80b022a7dafc").ordered.and_call_original
        InflatedBlock.check_inflation!({coin: :btc})
      end

      it "should create three new TxOutset entries" do
        InflatedBlock.check_inflation!({coin: :btc})
        expect(TxOutset.count).to eq(5)
        expect(TxOutset.fifth.total_amount - TxOutset.fourth.total_amount).to eq(12.5)
        expect(TxOutset.fourth.total_amount - TxOutset.third.total_amount).to eq(12.5)
        expect(TxOutset.third.total_amount - TxOutset.second.total_amount).to eq(12.5)
      end

    end

    describe "with extra inflation" do
      let(:user) { create(:user) }

      before do
        InflatedBlock.check_inflation!({coin: :btc})
        @node.mirror_client.mock_set_height(560178)
        @node.mirror_client.mock_set_extra_inflation(1)
      end

      it "should add a InflatedBlock entry" do
        begin
          InflatedBlock.check_inflation!({coin: :btc})
        rescue UncaughtThrowError
          # Ignore error
        end
        expect(InflatedBlock.count).to eq(1)
      end

      it "should mark txoutset as inflated" do
        begin
          InflatedBlock.check_inflation!({coin: :btc})
        rescue UncaughtThrowError
          # Ignore error
        end
        tx_outset = InflatedBlock.first.tx_outset
        expect(InflatedBlock.first.tx_outset.inflated).to eq(true)
      end

      it "should add a InflatedBlock entry for testnet inflation" do
        @node_testnet.mirror_client.mock_set_extra_inflation(1)
        begin
          InflatedBlock.check_inflation!({coin: :btc})
        rescue UncaughtThrowError
          # Ignore error
        end
        expect(InflatedBlock.count).to eq(1)
      end

      it "should send an alert" do
        expect(User).to receive(:all).and_return [user]
        expect {  InflatedBlock.check_inflation!({coin: :btc}) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "should send email only once" do
        expect(User).to receive(:all).and_return [user]
        expect {  InflatedBlock.check_inflation!({coin: :btc}) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect {  InflatedBlock.check_inflation!({coin: :btc}) }.to change { ActionMailer::Base.deliveries.count }.by(0)
      end

    end

  end
end
