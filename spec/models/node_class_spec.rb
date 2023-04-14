# frozen_string_literal: true

require 'rails_helper'
require 'bitcoind_helper'

RSpec.describe Node do
  let(:test) { TestWrapper.new }

  describe 'class' do
    describe 'set_pool_for_block!' do
      before do
        @block = create(:block, block_hash: '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377')
        @node = create(:node, block: @block, version: 160_000)

        @modern_node = create(:node, txindex: true)
        @modern_node.client.mock_set_height(560_178)
        @modern_node.poll!

        expect(described_class).to receive(:first_newer_than).with(160_000, :core).and_return @modern_node
      end

      it 'fetches the block' do
        expect(@modern_node.client).to receive('getblock').and_call_original
        described_class.set_pool_for_block!(@block)
      end

      it 'does not fetch the block if getblock is cached' do
        expect(@modern_node.client).not_to receive('getblock')
        described_class.set_pool_for_block!(@block,
                                            { height: 1, 'tx' => ['74e243e5425edfce9486e26aa6449e56c68351210e8edc1fe81ddcdc8d478085'] })
      end

      it 'calls getrawtransaction on the coinbase' do
        expect(@modern_node.client).to receive('getrawtransaction').and_call_original
        described_class.set_pool_for_block!(@block)
      end

      it 'passes getrawtransaction output to pool_from_coinbase_tx' do
        expect(Block).to receive(:pool_from_coinbase_tx)
        described_class.set_pool_for_block!(@block)
      end

      it 'calculates the total fee' do
        described_class.set_pool_for_block!(@block)
        expect(@block.total_fee).to eq(0.5)
      end
    end

    describe 'poll!' do
      it 'calls poll! on all nodes, followed by check_laggards!, check_chaintips! and check_versionbits!' do
        create(:node_with_block, version: 170_000)
        create(:node_with_block, version: 160_000)

        expect(described_class).to receive(:check_laggards!)

        expect(described_class).to receive(:check_chaintips!)

        # rubocop:disable RSpec/IteratedExpectation
        expect(described_class).to(receive(:bitcoin_core_by_version).and_wrap_original do |relation|
          relation.call.each do |node|
            expect(node).to receive(:poll!)
          end
        end)
        expect(described_class).to(receive(:bitcoin_core_by_version).and_wrap_original do |relation|
          relation.call.each do |node|
            expect(node).to receive(:check_versionbits!) if node.version == 170_000
          end
        end)

        # rubocop:enable RSpec/IteratedExpectation

        described_class.poll!
      end
    end

    describe 'poll_repeat!' do
      it 'calls poll!' do
        expect(described_class).to receive(:poll!).with({ repeat: true })

        described_class.poll_repeat!({})
      end
    end

    describe 'restore_mirror' do
      after do
        test.shutdown
      end

      before do
        test.setup
        allow(described_class).to receive('set_pool_for_block!').and_return(nil)
        @node = create(:node_python_with_mirror)
        @node.client.set_python_node(test.nodes[0])
        @node.client.createwallet
        @node.mirror_client.set_python_node(test.nodes[0]) # use same node for mirror
        @node.mirror_client.generate(2)
        @block_hash = @node.client.getbestblockhash
        @node.poll_mirror!
        @node.mirror_client.invalidateblock(@block_hash)
      end

      it 'restores network and reconsider blocks' do
        expect(@node.mirror_client).to receive('setnetworkactive').with(true)
        expect(@node.mirror_client).to receive('reconsiderblock').with(@block_hash)
        @node.restore_mirror
      end
    end

    describe 'rollback_checks_repeat!' do
      before do
        @node = create(:node_with_mirror)
        @node.mirror_client.mock_set_height(560_176)
        allow(Chaintip).to receive(:validate_forks!).and_return nil
        allow(InflatedBlock).to receive(:check_inflation!).and_return nil
        allow(Block).to receive(:find_missing).and_return nil
        allow(Chaintip).to receive(:validate_forks!).and_return nil
      end

      it 'checks inflation' do
        expect(InflatedBlock).to receive(:check_inflation!).with({ max: 10 })
        described_class.rollback_checks_repeat!
      end

      it 'checks for valid-headers chaintips' do
        expect(Chaintip).to receive(:validate_forks!)
        described_class.rollback_checks_repeat!
      end

      it 'calls find_missing' do
        expect(Block).to receive(:find_missing).with(40_000, 20)
        described_class.rollback_checks_repeat!
      end
    end

    describe 'heavy_checks_repeat!' do
      before do
        @node = create(:node_with_mirror)
        @node.mirror_client.mock_set_height(560_176)
        allow(described_class).to receive(:by_version).and_return [@node] # Preserve mirror client instance
        allow(described_class).to receive(:destroy_if_requested).and_return true
        allow(LightningTransaction).to receive(:check!).and_return true
        allow(LightningTransaction).to receive(:check_public_channels!).and_return true
        allow(Block).to receive(:find_missing).and_return true
        allow(StaleCandidate).to receive(:prime_cache).and_return true
        allow(Softfork).to receive(:notify!).and_return true
      end

      it 'runs Lightning checks' do
        expect(LightningTransaction).to receive(:check!).with({ max: 1000 })

        described_class.heavy_checks_repeat!
      end

      it 'calls check_public_channels!' do
        expect(LightningTransaction).to receive(:check_public_channels!)
        described_class.heavy_checks_repeat!
      end

      it 'calls match_missing_pools!' do
        expect(Block).to receive(:match_missing_pools!).with(3)
        described_class.heavy_checks_repeat!
      end

      it 'calls process_stale_candidates' do
        expect(StaleCandidate).to receive(:process!)
        described_class.heavy_checks_repeat!
      end

      it 'calls process_templates' do
        expect(Block).to receive(:process_templates!)
        described_class.heavy_checks_repeat!
      end
    end

    describe 'getblocktemplate_repeat!' do
      before do
        @node = create(:node)
        allow(described_class).to receive(:by_version).and_return [@node] # Preserve mirror client instance
      end

      it 'calls getblocktemplate' do
        expect(described_class).to receive(:getblocktemplate!)

        described_class.getblocktemplate_repeat!
      end
    end

    describe 'check_laggards!' do
      before do
        @node_a = build(:node)
        @node_a.client.mock_version(230_000)
        @node_a.poll!

        @node_b = build(:node)
        @node_b.client.mock_version(100_300)
        @node_b.poll!
      end

      it 'calls check_if_behind! against the newest node' do
        expect(described_class).to(receive(:bitcoin_core_by_version).and_wrap_original do |relation|
          relation.call.each do |record|
            if record.id == @node_a.id
              expect(record).not_to receive(:check_if_behind!)
            else
              expect(record).to receive(:check_if_behind!)
            end
          end
        end)
        described_class.check_laggards!
      end
    end

    describe 'check_chaintips!' do
      before do
        @node_a = build(:node)
        @node_a.client.mock_version(230_000)
        @node_a.poll!

        @node_b = build(:node)
        @node_b.client.mock_version(100_300)
        @node_b.poll!
      end

      it 'calls check! on Chaintip and on InvalidBlock' do
        expect(Chaintip).to receive(:check!).with([@node_a, @node_b])
        expect(InvalidBlock).to receive(:check!)
        described_class.check_chaintips!
      end
    end

    describe 'fetch_ancestors!' do
      before do
        @node_a = build(:node)
        @node_a.client.mock_version(230_000)
        @node_a.client.mock_set_height(560_178)
        @node_a.poll!

        @node_b = build(:node)
        @node_b.client.mock_version(100_300)
        @node_b.client.mock_set_height(560_178)
        @node_b.poll!
      end

      it 'calls find_ancestors! with the newest node' do
        expect(described_class).to(receive(:bitcoin_core_by_version).and_wrap_original do |relation|
          relation.call.each do |record|
            if record.id == @node_a.id
              expect(record.block).to receive(:find_ancestors!)
            else
              expect(record.block).not_to receive(:find_ancestors!)
            end
          end
        end)
        described_class.fetch_ancestors!(560_176)
      end
    end

    describe 'first_with_txindex' do
      before do
        @node_a = build(:node)
        @node_a.client.mock_version(230_000)
        @node_a.client.mock_set_height(560_178)
        @node_a.poll!
        # Explictly set to false, due to ugly hack in how the mock handles getindexinfo
        @node_a.update txindex: false

        @node_b = build(:node, txindex: true)
        @node_b.client.mock_version(100_300)
        @node_b.client.mock_set_height(560_178)
        @node_b.poll!
      end

      it 'throws if no node has txindex' do
        @node_b.update txindex: false
        expect { described_class.first_with_txindex }.to raise_error BitcoinUtil::RPC::NoTxIndexError
      end

      it 'returns node' do
        expect(described_class.first_with_txindex).to eq(@node_b)
      end
    end

    describe 'getrawtransaction' do
      before do
        @tx_id = '74e243e5425edfce9486e26aa6449e56c68351210e8edc1fe81ddcdc8d478085'
        @node_a = build(:node, txindex: true)
        @node_a.client.mock_version(230_000)
        @node_a.client.mock_set_height(560_178)
        @node_a.poll!
      end

      it 'calls getrawtransaction on a node with txindex' do
        expect(described_class).to receive(:first_with_txindex).and_return @node_a
        expect(@node_a).to receive(:getrawtransaction).with(@tx_id, false, nil)
        described_class.getrawtransaction(@tx_id)
      end
    end
  end
end
