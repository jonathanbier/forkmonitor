require 'rails_helper'

RSpec.describe LightningTransaction, type: :model do
  before do
    @node = build(:node, version: 170001)
    @node.client.mock_set_height(560176)
    @node.poll!
    @node.reload

    expect(Block.maximum(:height)).to eq(560176)
    allow(Node).to receive(:bitcoin_core_by_version).and_return [@node]

    # throw the first time for lacking a comparison block
    expect { LightningTransaction.check!({coin: :btc, max: 0}) }.to raise_error("More than 0 blocks behind for lightning checks, please manually check blocks before 560176 (0000000000000000000b1e380c92ea32288b0106ef3ed820db3b374194b15aab)")
    @node.client.mock_set_height(560177)
    @node.poll!
    @node.reload
  end

  describe "InflatedBlock.check_inflation!" do

    it "should mark lightning checks complete on each block" do
      expect(Block.find_by(height: 560176).checked_lightning).to eq(true)
    end

    it "should call check_penalties! on each block" do
      expect(LightningTransaction).to receive(:check_penalties!).with(Block.find_by(height: 560177), @node)
      LightningTransaction.check!({coin: :btc, max: 1})
    end

  end

  describe "check_penalties!" do
    before do
      @block = Block.find_by(height: 560177)
    end

    it "should fetch the raw block" do
      expect(@node.client).to receive(:getblock).with(@block.block_hash, 0)
      LightningTransaction.check_penalties!(@block, @node)
    end

  end
end
