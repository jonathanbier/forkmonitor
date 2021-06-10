# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PenaltyTransaction, type: :model do
  before do
    @node = build(:node, txindex: true)
    @node.client.mock_set_height(560_176)
    @node.poll!
    @node.reload

    expect(Block.maximum(:height)).to eq(560_176)
    allow(Node).to receive(:bitcoin_core_by_version).and_return [@node]

    allow(described_class).to receive(:check!).and_return nil

    # throw the first time for lacking a previously checked block
    expect do
      LightningTransaction.check!({ coin: :btc,
                                    max: 1 })
    end.to raise_error('Unable to perform lightning checks due to missing intermediate block')
    @node.client.mock_set_height(560_177)
    @node.poll!
    @node.reload
  end

  describe 'self.check!' do
    before do
      allow(described_class).to receive(:check!).and_call_original
      allow_any_instance_of(described_class).to receive(:get_opening_tx_id_and_block_hash!).and_return nil
      @block = Block.find_by(height: 560_177)
      raw_block = @node.client.getblock(@block.block_hash, 0)
      @parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      # Example from https://blog.bitmex.com/lightning-network-justice/
      @raw_tx_1 = '02000000000101031e7c67d770fb2a24eafd655f6013281e6ae34596649c07e6b4ee2d4a8dc25c000000000000000000014ef5050000000000160014befc2bfa5ad1be99da557f180ae91bd7b666d11403483045022100bd5c4c29e6b686aae5b6d0751e90208592ea96d26bc81d78b0d3871a94a21fa8022074dc2f971e438ccece8699c8fd15704c41df219ab37b63264f2147d15c3481d80101014d6321024cf55e52ec8af7866617dc4e7ff8433758e98799906d80e066c6f32033f685f967029000b275210214827893e2dcbe4ad6c20bd743288edad21100404eb7f52ccd6062fd0e7808f268ac00000000'
      @penalty_tx_1 = Bitcoin::Protocol::Tx.new([@raw_tx_1].pack('H*'))
      expect(@penalty_tx_1.hash).to eq('c5597bbe1f56ea72ae4b6e2835d69c1767c3ce1317da5352aa14dad8ed22df34')
      @parsed_block.tx.append(@penalty_tx_1)
      # Example with two inputs
      @raw_tx_2 = '020000000001029bdd4cf5f1cf39f7708e93eadeff5ba027f3dda125a48c08fb3054f1406706ee0000000000000000009bdd4cf5f1cf39f7708e93eadeff5ba027f3dda125a48c08fb3054f1406706ee01000000000000000001e09607000000000016001463fd6775c3c347edde97b25dc74661139e52697002483045022100bd11469620dbf948e434a0dd3e0a90c2479a9f02e2a824e07c1af2d44b8ed1e9022042313b5aa26c2efb950df96665ad358342b4e026d9977457509c98e8d95fbbd70121022c3fd7bafb4208bce1205dafebbfd9bbfec9fdf2c32f066fc681420dedda8fb903483045022100c1894b57f825767d9e5c52abf2b889915ea902867d4d829e0055acb0396aec8202205d7fb894beb4d758839158b71d01a14862e7f2cf5935a46bb2f4d5276f022f950101014d63210293e2c47436caee599f01fae3ea57ab8f2466eb299f5f76b5e8d5655196676bd167029000b275210200e29658ea97730030c73545f0c908b6c92adb1ee5ffe34b039363535116aea868ac00000000'
      @penalty_tx_2 = Bitcoin::Protocol::Tx.new([@raw_tx_2].pack('H*'))
      expect(@penalty_tx_2.hash).to eq('ec0d380f9b4539fc3426e97215d4dd896ace222161e48674df791d6540736606')
      @parsed_block.tx.append(@penalty_tx_2)
    end

    it 'finds penalty transactions' do
      described_class.check!(@node, @block, @parsed_block)
      expect(LightningTransaction.count).to eq(2)
    end

    it 'finds penalty transaction with one input' do
      described_class.check!(@node, @block, @parsed_block)
      expect(LightningTransaction.first.tx_id).to eq(@penalty_tx_1.hash)
      expect(LightningTransaction.first.raw_tx).to eq(@raw_tx_1)
    end

    it 'finds penalty transaction with two inputs' do
      described_class.check!(@node, @block, @parsed_block)
      expect(LightningTransaction.second.tx_id).to eq(@penalty_tx_2.hash)
      expect(LightningTransaction.second.raw_tx).to eq(@raw_tx_2)
    end

    it 'sets the amount based on the output' do
      described_class.check!(@node, @block, @parsed_block)
      expect(LightningTransaction.first.amount).to eq(0.00396375)
    end

    it 'finds opening transaction' do
      skip
    end
  end
end
