# frozen_string_literal: true

require 'rails_helper'
require 'bitcoind_helper'

RSpec.describe Node do
  let(:test) { new_test_wrapper }

  describe 'version' do
    it 'is set' do
      node = create(:node_with_block, version: 160_300)
      expect(node.version).to eq(160_300)
    end
  end

  describe 'name_with_version' do
    # More detailed tests in spec/lib/bitcoin_util/version_spec.rb
    it 'combines node name with version' do
      node = create(:node, version: 170_001)
      expect(node.name_with_version).to eq('Bitcoin Core 0.17.0.1')
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
      @node.getblock(@block_hash, :summary)
    end

    it 'throws ConnectionError' do
      @node.client.mock_connection_error(true)
      expect { @node.getblock(@block_hash, :summary) }.to raise_error BitcoinUtil::RPC::ConnectionError
    end

    it 'throws PartialFileError' do
      @node.client.mock_partial_file_error(true)
      expect { @node.getblock(@block_hash, :summary) }.to raise_error BitcoinUtil::RPC::PartialFileError
    end

    it 'throws BlockPrunedError' do
      @node.client.mock_block_pruned_error(true)
      expect { @node.getblock(@block_hash, :summary) }.to raise_error BitcoinUtil::RPC::BlockPrunedError
    end

    it 'throws BlockNotFullyDownloadedError' do
      @node.client.mock_block_not_fully_download_error(true)
      expect { @node.getblock(@block_hash, :summary) }.to raise_error BitcoinUtil::RPC::BlockNotFullyDownloadedError
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
      expect { @node.getblockheader(@block_hash) }.to raise_error BitcoinUtil::RPC::ConnectionError
    end

    it 'throws MethodNotFoundError' do
      @node.client.mock_version(100_000)
      expect { @node.getblockheader(@block_hash) }.to raise_error BitcoinUtil::RPC::MethodNotFoundError
    end
  end

  describe 'check_versionbits!' do
    before do
      @node = build(:node)
      @node.client.mock_version(230_000)
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
        expect { @node.check_versionbits! }.to(change { ActionMailer::Base.deliveries.count }.by(1))
      end

      it 'sends email only once' do
        expect { @node.check_versionbits! }.to(change { ActionMailer::Base.deliveries.count }.by(1))
        @node.client.mock_set_height(560_179)
        @node.poll!
        @node.reload
        expect { @node.check_versionbits! }.not_to(change { ActionMailer::Base.deliveries.count })
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
      @node.client.mock_version(230_000)
      @node.client.mock_set_height(560_178)
      @node.poll!
    end

    it 'calls getrawtransaction' do
      expect(@node.getrawtransaction(@tx_id)).to eq('010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff5303368c081a4d696e656420627920416e74506f6f6c633e007902205c4c4eadfabe6d6dd1950c951397395896a26405b01c17c50070f4a287b029b377eae4148bc9133f04000000000000005201000079650000ffffffff03478b704b000000001976a914edf10a7fac6b32e24daa5305c723f3de58db1bc888ac0000000000000000266a24aa21a9ed8d4ee584d2bd2483c525df85654a2fcfa9125638dd6fe56405a0590b3da0347800000000000000002952534b424c4f434b3ac6695c75ffa1f93f9237c6997abd16c988a3b442545478f81fd49d9af1b2ce9a0120000000000000000000000000000000000000000000000000000000000000000000000000')
    end

    it 'handles tx not found' do
      expect { @node.getrawtransaction(@tx_id.reverse) }.to raise_error BitcoinUtil::RPC::TxNotFoundError
    end
  end
end
