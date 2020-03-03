require 'rails_helper'

RSpec.describe LightningTransaction, type: :model do
  before do
    @node = build(:node, txindex: true)
    @node.client.mock_set_height(560176)
    @node.poll!
    @node.reload

    expect(Block.maximum(:height)).to eq(560176)
    allow(Node).to receive(:first_with_txindex).and_return @node

    allow(PenaltyTransaction).to receive(:check!).and_return nil
    allow(SweepTransaction).to receive(:check!).and_return nil

    # throw the first time for lacking a previously checked block
    expect{ LightningTransaction.check!({coin: :btc, max: 1}) }.to raise_error("Unable to perform lightning checks due to missing intermediate block")
    @node.client.mock_set_height(560177)
    @node.poll!
    @node.reload
  end

  describe "find_parent!" do
    let(:penalty_tx) { create(:penalty_transaction_public) }

    it "should find parent if available" do
      expect(penalty_tx.find_parent!).to be_nil
      parent = create(:parent_of_penalty)
      expect(penalty_tx.find_parent!).to eq(parent)
    end
  end

  describe "self.check!" do

    before do
      @block = Block.find_by(height: 560177)
    end

    it "should mark lightning checks complete on each block" do
      expect(Block.find_by(height: 560176).checked_lightning).to eq(true)
    end

    it "should fetch the raw block" do
      expect(@node.client).to receive(:getblock).with(@block.block_hash, 0).and_call_original
      expect(LightningTransaction.check!(coin: :btc, max: 1)).to eq(true)
    end

    it "should call PenaltyTransaction.check! with the parsed block" do
      raw_block = @node.client.getblock(@block.block_hash, 0)
      parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      expect(PenaltyTransaction).to receive(:check!).with(@node, @block, parsed_block)
      expect(LightningTransaction.check!(coin: :btc, max: 1)).to eq(true)
    end

    it "should call SweepTransaction.check! with the parsed block" do
      raw_block = @node.client.getblock(@block.block_hash, 0)
      parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      expect(SweepTransaction).to receive(:check!).with(@node, @block, parsed_block)
      expect(LightningTransaction.check!(coin: :btc, max: 1)).to eq(true)
    end

    it "should call MaybeUncoopTransaction.check! with the parsed block" do
      raw_block = @node.client.getblock(@block.block_hash, 0)
      parsed_block = Bitcoin::Protocol::Block.new([raw_block].pack('H*'))
      expect(MaybeUncoopTransaction).to receive(:check!).with(@node, @block, parsed_block)
      expect(LightningTransaction.check!(coin: :btc, max: 1)).to eq(true)
    end

    it "should gracefully fail if node connection is lost" do
      expect(@node).to receive(:getblock).and_raise(Node::ConnectionError)
      expect(LightningTransaction.check!(coin: :btc, max: 1)).to eq(false)
      @node.reload
      expect(@node.unreachable_since).not_to be_nil
    end

  end

  describe "check_public_channels!" do
    let(:block1) { create(:lightning_block) }
    let(:penalty_tx_public) { create(:penalty_transaction_public, block: block1) }
    let(:penalty_tx_private) { create(:penalty_transaction_private) }
    let(:uncoop_tx) { create(:maybe_uncoop_transaction, block: block1) }


    before do
      stub_request(:post, "https://1ml.com/search").with(
        body: "q=b4d8a795c033d60105c347347620fa0bd780f6a30cfd5dca7ce4df4102bd4cff"
      ).to_return(
        :status => 302,
        :headers => { 'Location' => "/channel/578407987470532609" }
      )
      stub_request(:post, "https://1ml.com/search").with(
        body: "q=1b9c2e929fa2dc3b29fe725841804563bb327437f0fad640010088467ef2870a"
      ).to_return(
        :status => 200
      )
      expect(penalty_tx_public.channel_is_public).to eq(nil)
      expect(penalty_tx_private.channel_is_public).to eq(nil)
      expect(uncoop_tx.channel_is_public).to eq(nil)

      LightningTransaction.check_public_channels!
      penalty_tx_public.reload
      penalty_tx_private.reload
      uncoop_tx.reload
    end

    it "should mark public channels as such" do
      expect(penalty_tx_public.channel_is_public).to eq(true)
      expect(penalty_tx_public.channel_id_1ml).to eq(578407987470532609)

      expect(uncoop_tx.channel_is_public).to eq(true)
      expect(uncoop_tx.channel_id_1ml).to eq(578407987470532609)
    end

    it "should mark private channels as such" do
      expect(penalty_tx_private.channel_is_public).to eq(false)
      expect(penalty_tx_private.channel_id_1ml).to be_nil
    end

  end
end
