require 'rails_helper'

RSpec.describe LightningTransaction, type: :model do
  before do
    @node = build(:node, version: 170001)
    @node.client.mock_set_height(560176)
    @node.poll!
    @node.reload

    expect(Block.maximum(:height)).to eq(560176)
    allow(Node).to receive(:bitcoin_core_by_version).and_return [@node]

    allow(LightningTransaction).to receive(:check_penalties!).and_return nil

    # throw the first time for lacking a comparison block
    expect { LightningTransaction.check!({coin: :btc, max: 0}) }.to raise_error("More than 0 blocks behind for lightning checks, please manually check blocks before 560176 (0000000000000000000b1e380c92ea32288b0106ef3ed820db3b374194b15aab)")
    @node.client.mock_set_height(560177)
    @node.poll!
    @node.reload
  end

  describe "InflatedBlock.check!" do

    before do
      @block = Block.find_by(height: 560177)
    end

    it "should mark lightning checks complete on each block" do
      expect(Block.find_by(height: 560176).checked_lightning).to eq(true)
    end

    it "should fetch the raw block" do
      expect(@node.client).to receive(:getblock).with(@block.block_hash, 0).and_call_original
      LightningTransaction.check!(coin: :btc, max: 1)
    end

    it "should call check_penalties! with the parsed block" do
      raw_block = @node.client.getblock(@block.block_hash, 0)
      parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      expect(LightningTransaction).to receive(:check_penalties!).with(@block, parsed_block)
      LightningTransaction.check!({coin: :btc, max: 1})
    end

  end

  describe "check_penalties!" do
    before do
      allow(LightningTransaction).to receive(:check_penalties!).and_call_original
      @block = Block.find_by(height: 560177)
      raw_block = @node.client.getblock(@block.block_hash, 0)
      @parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      # Example from https://blog.bitmex.com/lightning-network-justice/
      @raw_tx = "02000000000101031e7c67d770fb2a24eafd655f6013281e6ae34596649c07e6b4ee2d4a8dc25c000000000000000000014ef5050000000000160014befc2bfa5ad1be99da557f180ae91bd7b666d11403483045022100bd5c4c29e6b686aae5b6d0751e90208592ea96d26bc81d78b0d3871a94a21fa8022074dc2f971e438ccece8699c8fd15704c41df219ab37b63264f2147d15c3481d80101014d6321024cf55e52ec8af7866617dc4e7ff8433758e98799906d80e066c6f32033f685f967029000b275210214827893e2dcbe4ad6c20bd743288edad21100404eb7f52ccd6062fd0e7808f268ac00000000"
      @penalty_tx = Bitcoin::Protocol::Tx.new([@raw_tx].pack('H*'))
      expect(@penalty_tx.hash).to eq("c5597bbe1f56ea72ae4b6e2835d69c1767c3ce1317da5352aa14dad8ed22df34")
      @parsed_block.tx.append(@penalty_tx)
    end

    it "should find penalty transactions" do
      LightningTransaction.check_penalties!(@block, @parsed_block)
      expect(LightningTransaction.count).to eq(1)
      expect(LightningTransaction.first.tx_id).to eq(@penalty_tx.hash)
      expect(LightningTransaction.first.raw_tx).to eq(@raw_tx)
    end

    it "should set the amount based on the output" do
      LightningTransaction.check_penalties!(@block, @parsed_block)
      expect(LightningTransaction.first.amount).to eq(390478)
    end

  end
end
