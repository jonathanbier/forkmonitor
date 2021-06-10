# frozen_string_literal: true

require 'rails_helper'
require 'bitcoind_helper'

RSpec.describe Node, type: :model do
  let(:test) { TestWrapper.new }

  before do
    stub_const('BitcoinClient::Error', BitcoinClientMock::Error)
    stub_const('BitcoinClient::ConnectionError', BitcoinClientPython::ConnectionError)
    stub_const('BitcoinClient::TimeOutError', BitcoinClientPython::TimeOutError)
    stub_const('BitcoinClient::PartialFileError', BitcoinClientPython::PartialFileError)
    stub_const('BitcoinClient::BlockPrunedError', BitcoinClientPython::BlockPrunedError)
    stub_const('BitcoinClient::BlockNotFoundError', BitcoinClientPython::BlockNotFoundError)
    stub_const('BitcoinClient::MethodNotFoundError', BitcoinClientPython::MethodNotFoundError)
  end

  describe 'version' do
    it 'is set' do
      node = create(:node_with_block, version: 160_300)
      expect(node.version).to eq(160_300)
    end
  end

  describe 'name_with_version' do
    it 'combines node name with version' do
      node = create(:node, version: 170_001)
      expect(node.name_with_version).to eq('Bitcoin Core 0.17.0.1')
    end

    it 'handles 1.0 version' do
      node = create(:node, version: 1_000_000)
      expect(node.name_with_version).to eq('Bitcoin Core 1.0.0')
    end

    it 'handles clients that self identify with four digits' do
      node = create(:node, version: 1_060_000, client_type: :bu, name: 'Bitcoin Unlimited')
      expect(node.name_with_version).to eq('Bitcoin Unlimited 1.6.0.0')
    end

    it 'drops the 4th digit if zero' do
      node = create(:node, version: 170_000)
      expect(node.name_with_version).to eq('Bitcoin Core 0.17.0')
    end

    it 'appends version_extra' do
      node = create(:node, version: 170_000, version_extra: 'rc1')
      expect(node.name_with_version).to eq('Bitcoin Core 0.17.0rc1')
    end

    it 'hides version if absent' do
      node = create(:node, version: nil, client_type: :libbitcoin, name: 'Libbitcoin')
      expect(node.name_with_version).to eq('Libbitcoin')
    end

    it 'adds version_extra if set while version is absent' do
      node = create(:node, version: nil, client_type: :libbitcoin, name: 'Libbitcoin', version_extra: '3.6.0')
      expect(node.name_with_version).to eq('Libbitcoin 3.6.0')
    end
  end

  describe 'destroy' do
    it 'removes marked_(in)valid_by references in blocks' do
      node = create(:node, version: 170_001)
      node_id = node.id
      block_1 = create(:block, marked_valid_by: [node_id])
      block_2 = create(:block, marked_invalid_by: [node_id])
      node.destroy
      block_1.reload
      block_2.reload
      expect(block_1.marked_valid_by).not_to include(node_id)
      expect(block_2.marked_invalid_by).not_to include(node_id)
    end
  end

  describe 'getblock' do
    after do
      test.shutdown
    end

    before do
      test.setup
      @node = create(:node_python)
      @node.client.set_python_node(test.nodes[0])
      @node.client.createwallet
      @miner_addr = @node.client.getnewaddress
      @node.client.generatetoaddress(2, @miner_addr)
      @block_hash = @node.client.getbestblockhash
    end

    it 'calls getblock on the client' do
      expect(@node.client).to receive('getblock').and_call_original
      @node.getblock(@block_hash, 1)
    end

    it 'throws ConnectionError' do
      @node.client.mock_connection_error(true)
      expect { @node.getblock(@block_hash, 1) }.to raise_error Node::ConnectionError
    end

    it 'throws PartialFileError' do
      @node.client.mock_partial_file_error(true)
      expect { @node.getblock(@block_hash, 1) }.to raise_error Node::PartialFileError
    end

    it 'throws BlockPrunedError' do
      @node.client.mock_block_pruned_error(true)
      expect { @node.getblock(@block_hash, 1) }.to raise_error Node::BlockPrunedError
    end
  end

  describe 'getblockheader' do
    after do
      test.shutdown
    end

    before do
      test.setup
      @node = create(:node_python)
      @node.client.set_python_node(test.nodes[0])
      @node.client.createwallet
      @miner_addr = @node.client.getnewaddress
      @node.client.generatetoaddress(2, @miner_addr)
      @block_hash = @node.client.getbestblockhash
    end

    it 'calls getblockheader on the client' do
      expect(@node.client).to receive('getblockheader').and_call_original
      @node.getblockheader(@block_hash)
    end

    it 'throws ConnectionError' do
      @node.client.mock_connection_error(true)
      expect { @node.getblockheader(@block_hash) }.to raise_error Node::ConnectionError
    end

    it 'throws MethodNotFoundError' do
      @node.client.mock_version(100_000)
      expect { @node.getblockheader(@block_hash) }.to raise_error Node::MethodNotFoundError
    end
  end

  describe 'poll!' do
    describe 'on first run' do
      describe 'Bitcoin Core' do
        after do
          test.shutdown
        end

        before do
          stub_const('BitcoinClient::Error', BitcoinClientPython::Error)
          test.setup
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
          expect(@node.version).to be 219_900
        end

        it 'gets IBD status' do
          @node.poll!
          expect(@node.ibd).to eq(false)
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
      end

      describe 'other clients' do
        before do
          @node = build(:node)
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
        stub_const('BitcoinClient::Error', BitcoinClientPython::Error)
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
        expect(@node.ibd).to eq(false)
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
        expect(@node.ibd).to eq(true)

        @node.client.mock_ibd(false)
        @node.client.mock_set_height(560_179)
        @node.poll!
        expect(@node.ibd).to eq(false)
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
        expect(@node.ibd).to eq(false)
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

  describe 'check_if_behind!' do
    after do
      test.shutdown
    end

    before do
      # Two nodes at the same height
      test.setup(num_nodes: 2)
      @node_a = create(:node_python)
      @node_a.client.set_python_node(test.nodes[0])
      @node_a.client.createwallet
      @node_a.client.generate(2)

      @node_b = create(:node_python)
      @node_b.client.set_python_node(test.nodes[1])
      @node_b.client.createwallet

      test.sync_blocks
    end

    it 'detects if node A and B are at the same block' do
      expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
    end

    describe 'when behind' do
      let(:user) { create(:user) }

      before do
        allow(described_class).to receive('set_pool_tx_ids_fee_total_for_block!').and_return(nil)

        test.disconnect_nodes(0, 1)
        assert_equal(0, @node_a.client.getpeerinfo.count)

        @node_b.client.generate(1)
        allow(described_class).to receive(:bitcoin_core_by_version).and_return [@node_a, @node_b]

        described_class.poll!
        @node_a.peer_count = 1 # Bypass peer check in check_if_behind!
        @first_check = @node_a.check_if_behind!(@node_b)
        Timecop.freeze(Time.zone.now + 15 * 60)

        allow(User).to receive_message_chain(:all, :find_each).and_yield(user)
      end

      it 'is false if the difference is recent' do
        expect(@first_check).to eq(false)
      end

      it 'detects if node A is behind node B' do
        lag = @node_a.check_if_behind!(@node_b)
        expect(lag).not_to be_nil
        expect(lag.node_a).to eq(@node_a)
        expect(lag.node_b).to eq(@node_b)
      end

      it 'is nil if the node is unreachable' do
        @node_a.update unreachable_since: Time.zone.now
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
      end

      it 'is nil if the node is in initial block download' do
        @node_a.update ibd: true
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
      end

      it 'is nil if other node is in initial block download' do
        @node_b.update ibd: true
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
      end

      it 'is nil if the node has no peers' do
        @node_a.peer_count = 0
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
      end

      it 'allows extra blocks for old nodes' do
        @node_a.update version: 100_300
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
        @node_b.client.generate(3)
        described_class.poll!
        @node_a.update peer_count: 1, version: 100_300 # Undo override from poll
        expect(@node_a.check_if_behind!(@node_b)).not_to eq(nil)
      end

      it 'detects if bcoin node A is behind (core) node B' do
        @node_a.update version: '2.0.0'
        @node_a.update client_type: :bcoin

        lag = @node_a.check_if_behind!(@node_b)
        expect(lag).not_to be_nil
        expect(lag.node_a).to eq(@node_a)
        expect(lag.node_b).to eq(@node_b)
      end

      it 'allows extra blocks for btcd' do
        @node_a.update client_type: :btcd, version: 120_000
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)

        @node_b.client.generate(2)
        @node_a.update client_type: :core, version: 170_000 # Poll should use core
        described_class.poll!
        @node_a.update peer_count: 1, client_type: :btcd, version: 120_000
        expect(@node_a.check_if_behind!(@node_b)).not_to eq(nil)
      end

      it 'sends an email to all users' do
        expect { @node_a.check_if_behind!(@node_b) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it 'sends email only once' do
        expect { @node_a.check_if_behind!(@node_b) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect { @node_a.check_if_behind!(@node_b) }.to change { ActionMailer::Base.deliveries.count }.by(0)
      end
    end
  end

  describe 'check_versionbits!' do
    before do
      @node = build(:node)
      @node.client.mock_version(170_100)
      @node.client.mock_set_height(560_176)
      @node.poll!
      @node.client.mock_set_height(560_177)
      @node.poll!
    end

    describe 'during IBD' do
      before do
        @node.client.mock_ibd(true)
        @node.poll!
      end

      it 'does nothing' do
        @node.check_versionbits!
        expect(VersionBit.count).to eq(0)
      end
    end

    describe 'below threshold' do
      it 'does nothing' do
        @node.check_versionbits!
        expect(VersionBit.count).to eq(0)
      end
    end

    describe 'above threshold' do
      let(:user) { create(:user) }

      before do
        @node.client.mock_set_height(560_178)
        @node.poll!
        @node.reload

        allow(User).to receive_message_chain(:all, :find_each).and_yield(user)
      end

      it 'stores a VersionBit entry' do
        @node.check_versionbits!
        expect(VersionBit.count).to eq(1)
        expect(VersionBit.first.bit).to eq(1)
        expect(VersionBit.first.activate).to eq(@node.block)
      end

      it 'sends an email to all users' do
        expect { @node.check_versionbits! }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it 'sends email only once' do
        expect { @node.check_versionbits! }.to change { ActionMailer::Base.deliveries.count }.by(1)
        @node.client.mock_set_height(560_179)
        @node.poll!
        @node.reload
        expect { @node.check_versionbits! }.to change { ActionMailer::Base.deliveries.count }.by(0)
      end

      it 'leaves existing VersionBit entry alone' do
        @node.check_versionbits!
        @node.client.mock_set_height(560_179)
        @node.poll!
        @node.reload
        expect(@node.block.height).to eq(560_179)
        expect(@node.block.parent.height).to eq(560_178)
        @node.check_versionbits!
        expect(VersionBit.count).to eq(1)
        expect(VersionBit.first.bit).to eq(1)
        expect(VersionBit.first.activate).to eq(@node.block.parent)
      end

      it 'marks VersionBit entry inactive if not signalled for' do
        @node.check_versionbits!

        @node.client.mock_set_height(560_181)
        @node.poll!
        @node.reload
        @node.check_versionbits!
        expect(VersionBit.count).to eq(1)
        expect(VersionBit.first.deactivate).to eq(@node.block)

        @node.client.mock_set_height(560_182)
        @node.poll!
        @node.reload
        @node.check_versionbits!
        expect(VersionBit.count).to eq(1)
        expect(VersionBit.first.deactivate).to eq(@node.block.parent)
      end

      it 'does not mark VersionBit entry inactive too early' do
        @node.check_versionbits!

        @node.client.mock_set_height(560_180)
        @node.poll!
        @node.reload
        @node.check_versionbits!
        expect(VersionBit.count).to eq(1)
        expect(VersionBit.first.deactivate).to be_nil
      end
    end
  end

  # TODO: move to Block tests
  describe 'blockfind_ancestors!' do
    before do
      @node = build(:node)
      expect(Block.minimum(:height)).to equal(nil)
      @node.client.mock_set_height(560_179)
      @node.poll!
      @node.reload
      expect(@node.block.height).to equal(560_179)
      expect(Block.minimum(:height)).to equal(560_176)
    end

    it 'does not fetch parents before height 560176' do
      @node.block.find_ancestors!(@node, false, true)
      expect(Block.minimum(:height)).to equal(560_176)
    end

    it 'with block argument should fetch parents beyond the oldest block' do
      @node.client.mock_set_height(560_182)
      @node.poll!
      @node.reload
      expect(@node.block.height).to equal(560_182)
      expect(Block.count).to equal(7)

      @node.block.find_ancestors!(@node, false, true, 560_176)
      expect(Block.count).to equal(7)
      expect(Block.minimum(:height)).to equal(560_176)
    end
  end

  describe 'getrawtransaction' do
    before do
      @tx_id = '74e243e5425edfce9486e26aa6449e56c68351210e8edc1fe81ddcdc8d478085'
      @node = build(:node, txindex: true)
      @node.client.mock_version(170_100)
      @node.client.mock_set_height(560_178)
      @node.poll!
    end

    it 'calls getrawtransaction' do
      expect(@node.getrawtransaction(@tx_id)).to eq('010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff5303368c081a4d696e656420627920416e74506f6f6c633e007902205c4c4eadfabe6d6dd1950c951397395896a26405b01c17c50070f4a287b029b377eae4148bc9133f04000000000000005201000079650000ffffffff03478b704b000000001976a914edf10a7fac6b32e24daa5305c723f3de58db1bc888ac0000000000000000266a24aa21a9ed8d4ee584d2bd2483c525df85654a2fcfa9125638dd6fe56405a0590b3da0347800000000000000002952534b424c4f434b3ac6695c75ffa1f93f9237c6997abd16c988a3b442545478f81fd49d9af1b2ce9a0120000000000000000000000000000000000000000000000000000000000000000000000000')
    end

    it 'handles tx not found' do
      expect { @node.getrawtransaction(@tx_id.reverse) }.to raise_error Node::TxNotFoundError
    end
  end

  describe 'class' do
    describe 'set_pool_tx_ids_fee_total_for_block!' do
      before do
        @block = create(:block, block_hash: '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377')
        @node = create(:node, coin: :btc, block: @block, version: 160_000)

        @modern_node = create(:node, coin: :btc, txindex: true)
        @modern_node.client.mock_set_height(560_178)
        @modern_node.poll!

        expect(described_class).to receive(:first_newer_than).with(:btc, 160_000, :core).and_return @modern_node
      end

      it 'fetches the block' do
        expect(@modern_node.client).to receive('getblock').and_call_original
        described_class.set_pool_tx_ids_fee_total_for_block!(:btc, @block)
      end

      it 'does not fetch the block if getblock is cached' do
        expect(@modern_node.client).not_to receive('getblock')
        described_class.set_pool_tx_ids_fee_total_for_block!(:btc, @block,
                                                             { height: 1, 'tx' => ['74e243e5425edfce9486e26aa6449e56c68351210e8edc1fe81ddcdc8d478085'] })
      end

      it 'calls getrawtransaction on the coinbase' do
        expect(@modern_node.client).to receive('getrawtransaction').and_call_original
        described_class.set_pool_tx_ids_fee_total_for_block!(:btc, @block)
      end

      it 'passes getrawtransaction output to pool_from_coinbase_tx' do
        expect(Block).to receive(:pool_from_coinbase_tx)
        described_class.set_pool_tx_ids_fee_total_for_block!(:btc, @block)
      end

      it 'calculates the total fee' do
        described_class.set_pool_tx_ids_fee_total_for_block!(:btc, @block)
        expect(@block.total_fee).to eq(0.5)
      end
    end

    describe 'poll!' do
      it 'calls poll! on all nodes, followed by check_laggards!, check_chaintips! and check_versionbits!' do
        create(:node_with_block, coin: :btc, version: 170_000)
        create(:node_with_block, coin: :btc, version: 160_000)
        create(:node_with_block, coin: :bch)

        expect(described_class).to receive(:check_laggards!)

        expect(described_class).to receive(:check_chaintips!).with(:btc)
        expect(described_class).to receive(:check_chaintips!).with(:tbtc)
        expect(described_class).to receive(:check_chaintips!).with(:bch)

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

        expect(described_class).to(receive(:bch_by_version).once.and_wrap_original do |relation|
          relation.call.each do |node|
            expect(node).to receive(:poll!)
          end
        end)
        # rubocop:enable RSpec/IteratedExpectation

        described_class.poll!
      end
    end

    describe 'poll_repeat!' do
      it 'calls poll!' do
        expect(described_class).to receive(:poll!).with({ repeat: true, coins: ['BTC'] })

        described_class.poll_repeat!({ coins: ['BTC'] })
      end
    end

    describe 'restore_mirror' do
      after do
        test.shutdown
      end

      before do
        test.setup
        allow(described_class).to receive('set_pool_tx_ids_fee_total_for_block!').and_return(nil)
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
        expect(InflatedBlock).to receive(:check_inflation!).with({ coin: :btc, max: 10 })
        described_class.rollback_checks_repeat!({ coins: ['BTC'] })
      end

      it 'checks for valid-headers chaintips' do
        expect(Chaintip).to receive(:validate_forks!)
        described_class.rollback_checks_repeat!({ coins: ['BTC'] })
      end

      it 'calls find_missing' do
        expect(Block).to receive(:find_missing).with(:btc, 40_000, 20)
        described_class.rollback_checks_repeat!({ coins: ['BTC'] })
      end
    end

    describe 'heavy_checks_repeat!' do
      before do
        @node = create(:node_with_mirror)
        @node.mirror_client.mock_set_height(560_176)
        allow(described_class).to receive(:coin_by_version).with(:btc).and_return [@node] # Preserve mirror client instance
        allow(described_class).to receive(:destroy_if_requested).and_return true
        allow(LightningTransaction).to receive(:check!).and_return true
        allow(LightningTransaction).to receive(:check_public_channels!).and_return true
        allow(Block).to receive(:find_missing).and_return true
        allow(StaleCandidate).to receive(:prime_cache).and_return true
        allow(Softfork).to receive(:notify!).and_return true
      end

      it 'runs Lightning checks, on BTC only' do
        expect(LightningTransaction).to receive(:check!).with({ coin: :btc, max: 1000 })
        expect(LightningTransaction).not_to receive(:check!).with({ coin: :tbtc, max: 1000 })

        described_class.heavy_checks_repeat!({ coins: %w[BTC TBTC] })
      end

      it 'calls check_public_channels!' do
        expect(LightningTransaction).to receive(:check_public_channels!)
        described_class.heavy_checks_repeat!({ coins: ['BTC'] })
      end

      it 'calls match_missing_pools!' do
        expect(Block).to receive(:match_missing_pools!).with(:btc, 3)
        described_class.heavy_checks_repeat!({ coins: ['BTC'] })
      end

      it 'calls process_stale_candidates' do
        expect(StaleCandidate).to receive(:process!).with(:btc)
        described_class.heavy_checks_repeat!({ coins: ['BTC'] })
      end

      it 'calls process_templates' do
        expect(Block).to receive(:process_templates!).with(:btc)
        described_class.heavy_checks_repeat!({ coins: ['BTC'] })
      end
    end

    describe 'getblocktemplate_repeat!' do
      before do
        @node = create(:node)
        allow(described_class).to receive(:coin_by_version).with(:btc).and_return [@node] # Preserve mirror client instance
      end

      it 'calls getblocktemplate' do
        expect(described_class).to receive(:getblocktemplate!).with(:btc)

        described_class.getblocktemplate_repeat!({ coins: ['BTC'] })
      end
    end

    describe 'check_laggards!' do
      before do
        @node_a = build(:node)
        @node_a.client.mock_version(170_100)
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
        @node_a.client.mock_version(170_100)
        @node_a.poll!

        @node_b = build(:node)
        @node_b.client.mock_version(100_300)
        @node_b.poll!
      end

      it 'calls check! on Chaintip and on InvalidBlock' do
        expect(Chaintip).to receive(:check!).with(:btc, [@node_a, @node_b])
        expect(InvalidBlock).to receive(:check!)
        described_class.check_chaintips!(:btc)
      end
    end

    describe 'fetch_ancestors!' do
      before do
        @node_a = build(:node)
        @node_a.client.mock_version(170_100)
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
        @node_a.client.mock_version(170_100)
        @node_a.client.mock_set_height(560_178)
        @node_a.poll!

        @node_b = build(:node, txindex: true)
        @node_b.client.mock_version(100_300)
        @node_b.client.mock_set_height(560_178)
        @node_b.poll!
      end

      it 'is called with an known coin' do
        expect { described_class.first_with_txindex(:bbbbbbtc) }.to raise_error Node::InvalidCoinError
      end

      it 'throws if no node has txindex' do
        @node_b.update txindex: false
        expect { described_class.first_with_txindex(:btc) }.to raise_error Node::NoTxIndexError
      end

      it 'returns node' do
        expect(described_class.first_with_txindex(:btc)).to eq(@node_b)
      end
    end

    describe 'getrawtransaction' do
      before do
        @tx_id = '74e243e5425edfce9486e26aa6449e56c68351210e8edc1fe81ddcdc8d478085'
        @node_a = build(:node, txindex: true)
        @node_a.client.mock_version(170_100)
        @node_a.client.mock_set_height(560_178)
        @node_a.poll!
      end

      it 'calls getrawtransaction on a node with txindex' do
        expect(described_class).to receive(:first_with_txindex).with(:btc).and_return @node_a
        expect(@node_a).to receive(:getrawtransaction).with(@tx_id, false, nil)
        described_class.getrawtransaction(@tx_id, :btc)
      end
    end
  end
end
