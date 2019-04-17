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
  end
end
