require 'rails_helper'

RSpec.describe SweepTransaction, type: :model do
  before do
    @node = build(:node, version: 170001)
    @node.client.mock_set_height(560176)
    @node.poll!
    @node.reload

    expect(Block.maximum(:height)).to eq(560176)
    allow(Node).to receive(:bitcoin_core_by_version).and_return [@node]

    allow(SweepTransaction).to receive(:check!).and_return nil

    # throw the first time for lacking a previously checked block
    expect{ LightningTransaction.check!({coin: :btc, max: 1}) }.to raise_error("Unable to perform lightning checks due to missing intermediate block")
    @node.client.mock_set_height(560177)
    @node.poll!
    @node.reload
  end

  describe "check!" do
    before do
      allow(SweepTransaction).to receive(:check!).and_call_original
      allow_any_instance_of(SweepTransaction).to receive(:get_opening_tx_id!).and_return nil
      @block = Block.find_by(height: 560177)
      raw_block = @node.client.getblock(@block.block_hash, 0)
      @parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      # Example from https://blog.bitmex.com/lightning-network-justice/
      @raw_tx = "020000000001014438144650558e7291632e12b391bb8dbef71cc47dc4a13528d498f22f9934010000000000c000000001194a0000000000001600146ea99a7528fc731315728f0f00efb6f2f0dccdf20347304402201451ebe30475a01143838fea588a4e62a35f5d81ab095e09afaa7768f52eb7a102207a5ff5fbce0edb23a967a7e8acebb3f1f07274cc553ef767ab5e591fec38481301004d63210338b1ca63031787cac7aed7881d51d0fc2c7ce5d3fc38299012461b4c2d6957c96702c000b2752102bde439784dd33f266da6b32ec16d58a3e36500f3dbfbdef8e1e1dfe9d2b4b74a68ac00000000"
      @sweep_tx = Bitcoin::Protocol::Tx.new([@raw_tx].pack('H*'))
      expect(@sweep_tx.hash).to eq("a08e6620d21b8f451c63dfe8d0164f0ba1b2dc781ea163c7990634747b57282c")
      @parsed_block.tx.append(@sweep_tx)
    end

    it "should find sweep transactions" do
      SweepTransaction.check!(@block, @parsed_block)
      expect(LightningTransaction.count).to eq(1)
      expect(LightningTransaction.first.tx_id).to eq(@sweep_tx.hash)
      expect(LightningTransaction.first.raw_tx).to eq(@raw_tx)
    end

    it "should set the amount based on the output" do
      SweepTransaction.check!(@block, @parsed_block)
      expect(LightningTransaction.first.amount).to eq(0.00018969)
    end

    it "should find opening transaction" do
      skip()
    end

  end

end
