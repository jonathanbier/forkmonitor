# frozen_string_literal: true

require 'rails_helper'
require 'bitcoind_helper'

RSpec.describe InflatedBlock do
  let(:test) { TestWrapper.new }

  def setup_python_nodes
    @use_python_nodes = true

    test.setup(num_nodes: 3, extra_args: [['-whitelist=noban@127.0.0.1']] * 3)
    @node = create(:node_python_with_mirror)
    @node.client.set_python_node(test.nodes[0])
    @node.mirror_client.set_python_node(test.nodes[1])

    @node.client.generate(5)
    test.sync_blocks

    @node.poll!
    @node.poll_mirror!
    @node.reload
    expect(@node.block.height).to eq(5)
    expect(@node.block.parent.height).to eq(4)
    expect(Chaintip.count).to eq(0)
    expect(@node.mirror_block.height).to eq(5)

    @node_b = create(:node_python)
    @node_b.client.set_python_node(test.nodes[2])
    @node_b.client.createwallet
    @miner_addr = @node_b.client.getnewaddress
  end

  after do
    test.shutdown if @use_python_nodes
  end

  describe 'InflatedBlock.check_inflation!' do
    before do
      setup_python_nodes

      expect(Block.maximum(:height)).to eq(5)
      allow(Node).to receive(:with_mirror).with(:btc).and_return [@node]

      # throw the first time for lacking a comparison block
      expect { described_class.check_inflation!({ coin: :btc, max: 0 }) }.to raise_error(InflatedBlock::TooFarBehindError)
      expect(TxOutset.count).to eq(1)
      expect(@node.mirror_rest_until).not_to be_nil
      @node.update mirror_rest_until: nil
      # reconnect node with mirror node after network is restored
      test.connect_nodes(0, 1)
      test.connect_nodes(0, 2)

      @node.client.generate(1)
      test.sync_blocks
      @node.poll!
    end

    it "skips mirror node that's not synced" do
      @node.update mirror_block: nil
      allow(@node).to receive(:poll_mirror!).and_return nil
      expect(@node.mirror_client).not_to receive('setnetworkactive').with(false)
      described_class.check_inflation!({ coin: :btc, max: 1 })
    end

    it 'stops p2p networking and restart it after' do
      expect(@node.mirror_client).to receive('setnetworkactive').with(true) # restore
      expect(@node.mirror_client).to receive('setnetworkactive').with(false)
      expect(@node.mirror_client).to receive('setnetworkactive').with(true)
      described_class.check_inflation!({ coin: :btc, max: 1 })
    end

    it 'calls gettxoutsetinfo on BTC mirror node' do
      expect(@node).to receive(:poll_mirror!).and_call_original
      expect(@node.mirror_client).to receive('gettxoutsetinfo').and_call_original

      described_class.check_inflation!({ coin: :btc })

      expect(TxOutset.count).to eq(2)
      expect(TxOutset.last.block.height).to eq(6)
    end

    it "does not even poll the mirror if main node doesn't have a fresh block" do
      described_class.check_inflation!({ coin: :btc })
      expect(@node).not_to receive(:poll_mirror!)
      expect(@node.mirror_client).not_to receive('gettxoutsetinfo').and_call_original
      described_class.check_inflation!({ coin: :btc })
    end

    it 'does not call gettxoutsetinfo for block with existing tx outset info' do
      described_class.check_inflation!({ coin: :btc })
      expect(@node.mirror_client).not_to receive('gettxoutsetinfo').and_call_original
      described_class.check_inflation!({ coin: :btc })
    end

    it 'does not create duplicate TxOutset entries' do
      described_class.check_inflation!({ coin: :btc })
      described_class.check_inflation!({ coin: :btc })
      expect(TxOutset.count).to eq(2)
    end

    describe 'BTC mirror node has three more blocks' do
      before do
        @node.client.generate(2)
        test.sync_blocks
      end

      it 'fetches intermediate BTC blocks' do
        described_class.check_inflation!({ coin: :btc })
        expect(Block.maximum(:height)).to eq(8)
        expect(Block.find_by(height: 7)).not_to be_nil
        expect(Block.find_by(height: 6)).not_to be_nil
      end

      it 'invalidates the second block, and later the third block to wind back the tip' do
        @node.poll!
        block_hash_8 = Block.find_by(height: 8).block_hash
        block_hash_7 = Block.find_by(height: 7).block_hash
        expect(@node.mirror_client).to receive('invalidateblock').with(block_hash_7).ordered.and_call_original
        expect(@node.mirror_client).to receive('reconsiderblock').with(block_hash_7).ordered.and_call_original
        expect(@node.mirror_client).to receive('invalidateblock').with(block_hash_8).ordered.and_call_original
        expect(@node.mirror_client).to receive('reconsiderblock').with(block_hash_8).ordered.and_call_original
        described_class.check_inflation!({ coin: :btc })
      end

      it 'creates three new TxOutset entries' do
        described_class.check_inflation!({ coin: :btc })
        expect(TxOutset.count).to eq(4)
        expect(TxOutset.fourth.total_amount - TxOutset.third.total_amount).to eq(50)
        expect(TxOutset.third.total_amount - TxOutset.second.total_amount).to eq(50)
        expect(TxOutset.second.total_amount - TxOutset.first.total_amount).to eq(50)
      end
    end

    describe 'BTC mirror node has a valid-headers tip' do
      before do
        test.disconnect_nodes(2, 0)
        test.disconnect_nodes(2, 1)
        expect(@node_b.client.getpeerinfo.count).to eq(0)
        @node.client.generate(1)
        # Block at same height, but seen later by @node. It will be fetched,
        # but only validated up to valid-headers.
        # Use a new address so the block is different
        @node_b.client.generatetoaddress(1, @miner_addr)
        test.connect_nodes(2, 0)
        test.connect_nodes(2, 1)
        chaintips = @node.client.getchaintips
        expect(chaintips.count).to eq(2)
        expect(chaintips.select { |tip| tip['status'] == 'valid-headers' }.count).to eq(1)
      end

      it 'fetches the fork block' do
        described_class.check_inflation!({ coin: :btc })
        expect(Block.where(height: 7).count).to eq(2)
      end
    end

    describe 'BTC mirror node has a valid-fork' do
      before do
        test.disconnect_nodes(2, 0)
        test.disconnect_nodes(2, 1)
        expect(@node_b.client.getpeerinfo.count).to eq(0)
        # This will be the active tip until sync, when it's replaced with the
        # longer chain from node B. It then becomes a valid-fork.
        @node.client.generate(1)
        # Block at same height, but seen later by @node. It will be fetched,
        # but only validated up to valid-headers.
        # Use a new address so the block is different
        @node_b.client.generatetoaddress(2, @miner_addr)
        test.connect_nodes(2, 0)
        test.connect_nodes(2, 1)
        chaintips = @node.client.getchaintips
        expect(chaintips.count).to eq(2)
        expect(chaintips.select { |tip| tip['status'] == 'valid-fork' }.count).to eq(1)
      end

      it 'fetches the fork block' do
        described_class.check_inflation!({ coin: :btc })
        expect(Block.where(height: 7).count).to eq(2)
      end
    end

    describe 'with extra inflation' do
      let(:user) { create(:user) }

      before do
        described_class.check_inflation!({ coin: :btc })
        expect(@node.mirror_rest_until).not_to be_nil
        @node.update mirror_rest_until: nil
        # reconnect node with mirror node after network is restored
        test.connect_nodes(0, 1)
        test.connect_nodes(0, 2)
        @node.client.generate(1)
        test.sync_blocks
        @node.poll!
        @node.mirror_client.mock_set_extra_inflation(1.0)

        allow(User).to receive_message_chain(:all, :find_each).and_yield(user)
      end

      it 'adds a InflatedBlock entry' do
        begin
          described_class.check_inflation!({ coin: :btc })
        rescue UncaughtThrowError
          # Ignore error
        end
        expect(described_class.count).to eq(1)
      end

      it 'marks txoutset as inflated' do
        begin
          described_class.check_inflation!({ coin: :btc })
        rescue UncaughtThrowError
          # Ignore error
        end
        expect(described_class.first.tx_outset.inflated).to be(true)
      end

      it 'sends an alert' do
        expect { described_class.check_inflation!({ coin: :btc }) }.to (change do
          ActionMailer::Base.deliveries.count
        end).by(1)
      end

      it 'sends email only once' do
        expect { described_class.check_inflation!({ coin: :btc }) }.to (change do
          ActionMailer::Base.deliveries.count
        end).by(1)
        expect { described_class.check_inflation!({ coin: :btc }) }.not_to(change do
          ActionMailer::Base.deliveries.count
        end)
      end
    end
  end
end
