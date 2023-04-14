# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SweepTransaction do
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
      LightningTransaction.check!({ max: 1 })
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
      # Example with two sweeps in one transaction
      @raw_tx_1 = '0200000000010278e101c49650c59ba4acc5d02cc956ec5abaebdf5c254229421159a54a0c36cb0000000000ef000000339cfd86828c54f81845c415594f246b8711cf4c5115c9ae74dfe4401bde21c2000000000090000000011f020000000000001600141198e1682178aca213b640f53c88d2ad712036530347304402204de982bd5bc26a9190082310c0f230b47793c6b3012d8dff208482c34f8ae52f022004bee421d9f50d4037dcc15ec8e3230516e0c446ed345bcea3b5f2550625018e01004d6321034935a5c7a6035b8f63b0341971a739cb0606ef840dc8a2d40ac1d353cc4379d56702ef00b27521036f593acbcfc12fe33b7d3a15db51d124852e05bccfdbdff5f75aaa68e4bed6e368ac0347304402206a396c9cbd3a90e7640fff0968da1751ba526220c49a77539f5aeb5739b53e0d02201976b8bd708f4ed660d76440939f90495ada2beaee665026176d2dfea828662201004d6321022f9d8811df37a61d5a76b9b545a6e7511af92ce5119462143945cb44737abf7e67029000b27521034214c3f3acb850f699353111c13c46f69e18169a599a6d734f9248c4516719b368accdf60800'
      @sweep_tx_1 = Bitcoin::Protocol::Tx.new([@raw_tx_1].pack('H*'))
      expect(@sweep_tx_1.hash).to eq('4930425fe3af461e0b7947217c1d3be946007b05ab523467306b76dd8136ffe0')
      @parsed_block.tx.append(@sweep_tx_1)
      # Example with one sweep, not the first input:
      @raw_tx_2 = '020000000001039000c8c92b528b5001233d16b7ba9f2182f2427c478ea15ffb15e84526442bed01000000000000000078173776687b2e4d7bed4581febd32e4d6258d0ff33b723a9889523d23185403000000000090000000c16838b15cac5444c2dbc903757c1bd0d078bc91b33bcfe45d278f57f752525300000000000000000001e9490600000000001600142f2a598123a5babc24c8fdfd238969d0143e3d1902483045022100f7db646ec1f28dad5de6b12ef1d0aecdfc7c0519ee6665491a746bfe8b03ad910220235756ade345c3e96dfa332f88de08153842e31e106874206b6c271adb6d8e3201210299e4826eed340576f37caa659caa626c09b10447d30f3dc6e2e7cbb332c7c19703473044022009834c3c3a7ba0f5964d0ea2f5e1ebacc08948debaef73fbd244739d5539efb602200e261bee02a4eda0ce3900c52b8500c6d5009874e9cd0e62fa5d182591bcdbd001004d63210272017d37998fdf533144dc1e8a81a5313f7dc2bf88d869c989331f558e7fd54367029000b2752102ea76207c0c7cc2c80b35833e3b1e25dd245b3014ac8cd57f7d8725825527b4d368ac02483045022100f1807718640a0c0d519b1b3b603395d2aa8c34d7805bda258a181deed67ee7ed02201afb9529a0079b92e200181aa6c377464d90aa95e63d8e2ccf7a95a33de9a2d80121026279e19bf061bc779923b2524f325a894fbf91534415c168fee6115a347cba4f1e950800'
      @sweep_tx_2 = Bitcoin::Protocol::Tx.new([@raw_tx_2].pack('H*'))
      expect(@sweep_tx_2.hash).to eq('fdb69e3687acc067aec34d764246e610ee337f35ab765602fae579a413ab57ad')
      @parsed_block.tx.append(@sweep_tx_2)
    end

    it 'finds sweep transactions' do
      described_class.check!(@node, @block, @parsed_block)
      expect(LightningTransaction.count).to eq(3)
    end

    it 'finds sweep transactions with two sweep inputs' do
      described_class.check!(@node, @block, @parsed_block)
      expect(LightningTransaction.first.tx_id).to eq(@sweep_tx_1.hash)
      expect(LightningTransaction.first.input).to eq(0)
      expect(LightningTransaction.first.raw_tx).to eq(@raw_tx_1)
      expect(LightningTransaction.second.tx_id).to eq(@sweep_tx_1.hash)
      expect(LightningTransaction.second.input).to eq(1)
    end

    it 'finds transactions with one sweep and one non-sweep input' do
      described_class.check!(@node, @block, @parsed_block)
      expect(LightningTransaction.third.tx_id).to eq(@sweep_tx_2.hash)
      expect(LightningTransaction.third.input).to eq(1)
      expect(LightningTransaction.third.raw_tx).to eq(@raw_tx_2)
    end

    it 'sets the amount based on the output' do
      described_class.check!(@node, @block, @parsed_block)
      expect(LightningTransaction.first.amount).to eq(0.00001002)
      expect(LightningTransaction.second.amount).to eq(0.00001001)
    end
  end
end
