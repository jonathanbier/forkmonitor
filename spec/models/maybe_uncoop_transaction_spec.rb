# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MaybeUncoopTransaction, type: :model do
  before do
    @node = build(:node, txindex: true)
    @node.client.mock_set_height(560_176)
    @node.poll!
    @node.reload

    expect(Block.maximum(:height)).to eq(560_176)
    allow(Node).to receive(:bitcoin_core_by_version).and_return [@node]

    allow(MaybeUncoopTransaction).to receive(:check!).and_return nil

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
      allow(MaybeUncoopTransaction).to receive(:check!).and_call_original
      allow_any_instance_of(MaybeUncoopTransaction).to receive(:get_opening_tx_id_and_block_hash!).and_return '5cc28d4a2deeb4e6079c649645e36a1e2813605f65fdea242afb70d7677c1e03',
                                                                                                              '0000000000000000001a93e4264f21d6c2c525c09130074ec81eb9980bcc08c0'
      @block = Block.find_by(height: 560_177)
      raw_block = @node.client.getblock(@block.block_hash, 0)
      @parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      # Parent transaction of example in PenaltyTransaction spec
      @raw_tx = '02000000000101035a5987fe0e8e09596025028af5d102513a3cae0e359ec91afd11f23f01e9d101000000002ccd588001570c06000000000022002089e84892873c679b1129edea246e484fd914c2601f776d4f2f4a001eb8059703040047304402200cd723a1dcd37dc9b4b540edb34fbf83225d06b6bb5259e4e916da7dec867ed902207d6339f0d9761a3d880d912948fd4677357c8ba0aa1da060b91f8fc142ae587301483045022100d6851c4c7c4b2adcc191f29df2ebf932ef05849724bc302f80c008fe001cecd3022021772b06864d27773a3111bbb1a8cb3956ade831e15e6a769bfb5747bdd712b60147522102472f2625341c1a90aae28cfaabc20006bca11236aa9eb95552e9b2f3c422fca8210367030db2ae7ab0d17a41e0318d054a223b5292f006e6e0c7fa224df37e4babb052ae47796020'
      @uncoop_tx = Bitcoin::Protocol::Tx.new([@raw_tx].pack('H*'))
      expect(@uncoop_tx.hash).to eq('5cc28d4a2deeb4e6079c649645e36a1e2813605f65fdea242afb70d7677c1e03')
      @parsed_block.tx.append(@uncoop_tx)
    end

    it 'should find uncooperative closing transactions' do
      MaybeUncoopTransaction.check!(@node, @block, @parsed_block)
      expect(MaybeUncoopTransaction.count).to eq(1)
      expect(MaybeUncoopTransaction.first.tx_id).to eq(@uncoop_tx.hash)
      expect(MaybeUncoopTransaction.first.input).to eq(0)
      expect(MaybeUncoopTransaction.first.raw_tx).to eq(@raw_tx)
    end

    it 'should set the amount based on the output' do
      MaybeUncoopTransaction.check!(@node, @block, @parsed_block)
      expect(MaybeUncoopTransaction.first.amount).to eq(0.00396375)
    end

    it 'should find opening transaction' do
      skip
    end
  end
end
