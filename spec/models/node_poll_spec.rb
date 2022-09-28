# frozen_string_literal: true

require 'rails_helper'
require 'bitcoind_helper'

RSpec.describe Node, type: :model do
  let(:test) { TestWrapper.new }

  describe 'poll!' do
    describe 'on first run' do
      describe 'Bitcoin Core' do
        after do
          test.shutdown
        end

        before do
          test.setup(extra_args: [
                       [
                         '-txindex'
                       ]
                     ])
          @node = create(:node_python)
          @node.client.set_python_node(test.nodes[0])
          @node.client.createwallet
          @miner_addr = @node.client.getnewaddress
          @node.client.generatetoaddress(2, @miner_addr)
          allow(described_class).to receive('set_pool_tx_ids_fee_total_for_block!').and_return(nil)
        end

        it 'saves the node' do
          @node.poll!
          expect(@node.id).not_to be_nil
        end

        it 'stores the node version' do
          @node.poll!
          expect(@node.version).to be 230_000
        end

        it 'gets IBD status' do
          @node.poll!
          expect(@node.ibd).to be(false)
        end

        it 'does not store the latest block if in IBD' do
          allow(@node).to receive('ibd').and_return(true)
          @node.poll!
          expect(@node.block).to be_nil
        end

        # TODO: figure out how to put a regtest node in an IBD state
        # it "should store sync height if in IBD" do
        #   allow(@node).to receive("ibd").and_return(true)
        #   @node.poll!
        #   expect(@node.sync_height).to eq(2)
        # end

        it 'stores the latest block if not in IBD' do
          @node.poll!
          expect(@node.block).not_to be_nil
          expect(@node.block.height).to eq(2)
          expect(@node.block.first_seen_by).to eq(@node)
        end

        it 'gets mempool size' do
          @node.client.generatetoaddress(100, @miner_addr)
          @node.client.sendtoaddress(@node.client.getnewaddress, 0.1)
          @node.poll!
          expect(@node.mempool_bytes).to be_within(2).of(141)
          expect(@node.mempool_count).to eq(1)
          expect(@node.mempool_max).to eq(300_000_000)
        end

        it 'stores index status for >= 0.21' do
          @node.poll!
          expect(@node.txindex).to be(true)
        end
      end

      describe 'other clients' do
        before do
          @node = build(:node, client_type: :bcoin)
          @node.client.mock_ibd(true)
        end

        it 'parses 2.0.0 variant (e.g. Bcoin)' do
          @node.client.mock_version('2.0.0')
          @node.client.mock_client_type(:bcoin)
          @node.poll!
          expect(@node.version).to eq(2_000_000)
        end
      end
    end

    describe 'on subsequent runs' do
      before do
        test.setup
        @node = create(:node_python)
        @node.client.set_python_node(test.nodes[0])
        @node.client.createwallet
        @miner_addr = @node.client.getnewaddress
        @node.client.generatetoaddress(2, @miner_addr)
        expect(described_class).to receive('set_pool_tx_ids_fee_total_for_block!').at_least(:once).and_return(nil)
        @node.poll! # stores the block and node entry
      end

      after do
        test.shutdown
      end

      it 'gets IBD status' do
        @node.poll!
        expect(@node.ibd).to be(false)
      end

      it 'updates to the latest block' do
        @node.poll!
        expect(@node.block.height).to equal(2)
      end

      it 'stores size and number of transactions in block' do
        @node.client.generate(1)
        @node.poll!
        expect(@node.block.tx_count).to eq(1)
        expect(@node.block.size).to be_between(249, 254).inclusive
      end

      it 'stores intermediate blocks' do
        @node.client.generate(2)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(4)
        expect(@node.block.parent).not_to be_nil
        expect(@node.block.parent.height).to equal(3)
        expect(@node.block.parent.first_seen_by).to eq(@node)
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(2)
      end

      it 'does not store blocks during initial blockchain download' do
        @node.client.generate(2)
        allow(@node).to receive('ibd').and_return(true)
        @node.poll!
        @node.reload
        expect(@node.block).to be_nil
      end

      it 'does not fetch parent blocks older than MINIMUM_BLOCK_HEIGHTS' do
        # Exit IBD, fetching all previous blocks would take forever, so don't:
        @node.client.generate(2)
        # rubocop:disable RSpec/LeakyConstantDeclaration
        before = Block::MINIMUM_BLOCK_HEIGHTS[:btc]
        Kernel.silence_warnings do
          Block::MINIMUM_BLOCK_HEIGHTS = { btc: 4 }.freeze
        end
        @node.poll!
        Kernel.silence_warnings do
          Block::MINIMUM_BLOCK_HEIGHTS = { btc: before }.freeze
        end
        # rubocop:enable RSpec/LeakyConstantDeclaration
        @node.reload
        expect(@node.block.height).to equal(4)
        expect(@node.block.parent).to be_nil

        @node.client.generate(2)

        # Two blocks later, now it should fetch intermediate blocks:
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(6)
        expect(@node.block.parent.height).to equal(5)
      end

      it 'detects when node becomes unreachable' do
        test.shutdown
        @node.poll!
        test.setup
        expect(@node.unreachable_since).not_to be_nil
      end

      it 'detects when node becomes reachable' do
        @node.update unreachable_since: Time.zone.now
        expect(@node.unreachable_since).not_to be_nil
        @node.poll!
        expect(@node.unreachable_since).to be_nil
      end
    end

    describe 'Bitcoin Core 0.13.0' do
      before do
        allow(described_class).to receive('set_pool_tx_ids_fee_total_for_block!').and_return(nil)
        @node = build(:node)
        @node.client.mock_version(130_000)
        @node.client.mock_set_height(560_177)
        @node.poll! # First poll stores the block and node entry
      end

      it 'gets IBD status from verificationprogress' do
        @node.client.mock_ibd(true)
        @node.client.mock_set_height(976)
        @node.poll!
        expect(@node.ibd).to be(true)

        @node.client.mock_ibd(false)
        @node.client.mock_set_height(560_179)
        @node.poll!
        expect(@node.ibd).to be(false)
      end

      it 'stores intermediate blocks' do
        @node.client.mock_set_height(560_179)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560_179)
        expect(@node.block.parent).not_to be_nil
        expect(@node.block.parent.height).to equal(560_178)
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(560_177)
      end
    end

    describe 'Bitcoin Core 0.10.3' do
      before do
        allow(described_class).to receive('set_pool_tx_ids_fee_total_for_block!').and_return(nil)
        @node = build(:node)
        @node.client.mock_version(100_300)
        @node.poll!
      end

      it 'gets IBD status from verificationprogress' do
        @node.client.mock_ibd(true)
        expect(@node.ibd).to be(false)
      end

      it 'uses time from getblock instead of getblockchaininfo' do
        expect(@node.block.timestamp).to equal(1_548_498_742)
      end

      it 'stores intermediate blocks' do
        @node.client.mock_set_height(560_179)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560_179)
        expect(@node.block.parent).not_to be_nil
        expect(@node.block.parent.height).to equal(560_178)
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(560_177)
        expect(@node.block.parent.parent.timestamp).to equal(1_548_500_251)
      end
    end

    describe 'btcd' do
      before do
        allow(described_class).to receive('set_pool_tx_ids_fee_total_for_block!').and_return(nil)
        @node = build(:node, client_type: :btcd)
        @node.client.mock_client_type(:btcd)
        @node.client.mock_version(120_000)
        @node.poll!
      end

      it 'has correct data' do
        expect(@node.version).to equal(120_000)
        expect(@node.block.height).to equal(560_176)
      end

      it 'stores intermediate blocks' do
        @node.client.mock_set_height(560_178)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560_178)
        expect(@node.block.parent.parent).not_to be_nil
      end
    end
  end

  describe 'poll_mirror!' do
    before do
      @node = build(:node_with_mirror)
      @node_without_mirror = build(:node)

      @node.client.mock_set_height(560_177)
      @node_without_mirror.client.mock_set_height(560_177)
      @node.mirror_client.mock_set_height(560_177)

      @node.poll! # stores the block and node entry
    end

    it 'node without mirror node should not have mirror_client' do
      n = build(:node)
      expect(n.mirror_client).to be_nil
    end

    # Polling the mirror node while it's performing an expensive operation
    # will slow down the regular polling operation.
    it 'poll! should not poll mirror node' do
      @node.poll!
      expect(@node.mirror_block).to be_nil
    end

    it 'poll_mirror! should poll mirror node' do
      @node.poll_mirror!
      expect(@node.mirror_block.height).to equal(560_177)
    end

    it "poll_mirror! should do nothing if a node doesn't have a mirror" do
      @node_without_mirror.poll_mirror!
      expect(@node.mirror_block).to be_nil
    end
  end
end
