require 'rails_helper'

RSpec.describe SweepTransaction, type: :model do
  before do
    @node = build(:node, version: 170001, txindex: true)
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
      # Example with two sweeps in one transaction
      @raw_tx = "0200000000010278e101c49650c59ba4acc5d02cc956ec5abaebdf5c254229421159a54a0c36cb0000000000ef000000339cfd86828c54f81845c415594f246b8711cf4c5115c9ae74dfe4401bde21c2000000000090000000011f020000000000001600141198e1682178aca213b640f53c88d2ad712036530347304402204de982bd5bc26a9190082310c0f230b47793c6b3012d8dff208482c34f8ae52f022004bee421d9f50d4037dcc15ec8e3230516e0c446ed345bcea3b5f2550625018e01004d6321034935a5c7a6035b8f63b0341971a739cb0606ef840dc8a2d40ac1d353cc4379d56702ef00b27521036f593acbcfc12fe33b7d3a15db51d124852e05bccfdbdff5f75aaa68e4bed6e368ac0347304402206a396c9cbd3a90e7640fff0968da1751ba526220c49a77539f5aeb5739b53e0d02201976b8bd708f4ed660d76440939f90495ada2beaee665026176d2dfea828662201004d6321022f9d8811df37a61d5a76b9b545a6e7511af92ce5119462143945cb44737abf7e67029000b27521034214c3f3acb850f699353111c13c46f69e18169a599a6d734f9248c4516719b368accdf60800"
      @sweep_tx = Bitcoin::Protocol::Tx.new([@raw_tx].pack('H*'))
      expect(@sweep_tx.hash).to eq("4930425fe3af461e0b7947217c1d3be946007b05ab523467306b76dd8136ffe0")
      @parsed_block.tx.append(@sweep_tx)
    end

    it "should find sweep transactions" do
      SweepTransaction.check!(@node, @block, @parsed_block)
      expect(LightningTransaction.count).to eq(2)
      expect(LightningTransaction.first.tx_id).to eq(@sweep_tx.hash)
      expect(LightningTransaction.first.input).to eq(0)
      expect(LightningTransaction.first.raw_tx).to eq(@raw_tx)
      expect(LightningTransaction.second.tx_id).to eq(@sweep_tx.hash)
      expect(LightningTransaction.second.input).to eq(1)
    end

    it "should set the amount based on the output" do
      SweepTransaction.check!(@node, @block, @parsed_block)
      expect(LightningTransaction.first.amount).to eq(0.00001002)
      expect(LightningTransaction.second.amount).to eq(0.00001001)
    end

    it "should find opening transaction" do
      skip()
    end

  end

end
