require "rails_helper"

RSpec.describe Block, :type => :model do
  describe "log2_pow" do
    it "should be log2(pow)" do
      block = create(:block, work: "00000000000000000000000000000001")
      expect(block.log2_pow).to eq(0.0)
      block = create(:block, work: "00000000000000000000000000000002")
      expect(block.log2_pow).to eq(1.0)
    end
  end

  describe "self.check_inflation!" do
    before do
      @node = build(:node, version: 170001)
      @node.client.mock_set_height(560176)
      @node.poll!
      @node.reload
      expect(Block.maximum(:height)).to eq(560176)
      allow(Node).to receive(:bitcoin_by_version).and_return [@node]
    end

    it "should call gettxoutsetinfo" do
      Block.check_inflation!
      expect(TxOutset.count).to eq(1)
      expect(TxOutset.first.block.height).to eq(560176)
    end

    it "should not create duplicate TxOutset entries" do
      Block.check_inflation!
      Block.check_inflation!
      expect(TxOutset.count).to eq(1)
    end

    describe "two different blocks" do
      before do
        Block.check_inflation!

        @node.client.mock_set_height(560178)
        Block.check_inflation!
      end

      it "should fetch intermediate blocks" do
        expect(Block.maximum(:height)).to eq(560178)
        expect(TxOutset.count).to eq(2)
        expect(TxOutset.last.block.height).to eq(560178)
      end

      it "mock UTXO set should have increase by be 2 x 12.5 BTC" do
        expect(TxOutset.last.total_amount - TxOutset.first.total_amount).to eq(25.0)
      end
    end
  end
end
