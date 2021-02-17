require "rails_helper"
require "bitcoind_helper"

RSpec.describe Node, :type => :model do
  let(:test) { TestWrapper.new() }

  before do
    stub_const("BitcoinClient::Error", BitcoinClientMock::Error)
    stub_const("BitcoinClient::ConnectionError", BitcoinClientPython::ConnectionError)
    stub_const("BitcoinClient::TimeOutError", BitcoinClientPython::TimeOutError)
    stub_const("BitcoinClient::PartialFileError", BitcoinClientPython::PartialFileError)
    stub_const("BitcoinClient::BlockPrunedError", BitcoinClientPython::BlockPrunedError)
    stub_const("BitcoinClient::BlockNotFoundError", BitcoinClientPython::BlockNotFoundError)
    stub_const("BitcoinClient::MethodNotFoundError", BitcoinClientPython::MethodNotFoundError)
  end

  describe "version" do
    it "should be set" do
      node = create(:node_with_block, version: 160300)
      expect(node.version).to eq(160300)
    end
  end

  describe "name_with_version" do
    it "should combine node name with version" do
      node = create(:node, version: 170001)
      expect(node.name_with_version).to eq("Bitcoin Core 0.17.0.1")
    end

    it "should handle 1.0 version" do
      node = create(:node, version: 1000000)
      expect(node.name_with_version).to eq("Bitcoin Core 1.0.0")
    end

    it "should handle clients that self identify with four digits" do
      node = create(:node, version: 1060000, client_type: :bu, name: "Bitcoin Unlimited")
      expect(node.name_with_version).to eq("Bitcoin Unlimited 1.6.0.0")
    end

    it "should drop the 4th digit if zero" do
      node = create(:node, version: 170000)
      expect(node.name_with_version).to eq("Bitcoin Core 0.17.0")
    end

    it "should append version_extra" do
      node = create(:node, version: 170000, version_extra: "rc1")
      expect(node.name_with_version).to eq("Bitcoin Core 0.17.0rc1")
    end

    it "should hide version if absent" do
      node = create(:node, version: nil, client_type: :libbitcoin, name: "Libbitcoin")
      expect(node.name_with_version).to eq("Libbitcoin")
    end

    it "should add version_extra if set while version is absent" do
      node = create(:node, version: nil, client_type: :libbitcoin, name: "Libbitcoin", version_extra: "3.6.0")
      expect(node.name_with_version).to eq("Libbitcoin 3.6.0")
    end

  end

  describe "destroy" do
    it "should remove marked_(in)valid_by references in blocks" do
      node = create(:node, version: 170001)
      node_id = node.id
      block1 = create(:block, marked_valid_by: [node_id])
      block2 = create(:block, marked_invalid_by: [node_id])
      node.destroy
      block1.reload
      block2.reload
      expect(block1.marked_valid_by).not_to include(node_id)
      expect(block2.marked_invalid_by).not_to include(node_id)
    end
  end

  describe "getblock" do
    after do
      test.shutdown()
    end

    before do
      test.setup()
      @node = create(:node_python)
      @node.client.set_python_node(test.nodes[0])
      @node.client.generate(2)
      @block_hash = @node.client.getbestblockhash()
    end

    it "should call getblock on the client" do
      expect(@node.client).to receive("getblock").and_call_original()
      @node.getblock(@block_hash, 1)
    end

    it "should throw ConnectionError" do
      @node.client.mock_connection_error(true)
      expect { @node.getblock(@block_hash, 1) }.to raise_error Node::ConnectionError
    end

    it "should throw PartialFileError" do
      @node.client.mock_partial_file_error(true)
      expect { @node.getblock(@block_hash, 1) }.to raise_error Node::PartialFileError
    end

    it "should throw BlockPrunedError" do
      @node.client.mock_block_pruned_error(true)
      expect { @node.getblock(@block_hash, 1) }.to raise_error Node::BlockPrunedError
    end

  end

  describe "getblockheader" do
    after do
      test.shutdown()
    end

    before do
      test.setup()
      @node = create(:node_python)
      @node.client.set_python_node(test.nodes[0])
      @node.client.generate(2)
      @block_hash = @node.client.getbestblockhash()
    end

    it "should call getblockheader on the client" do
      expect(@node.client).to receive("getblockheader").and_call_original()
      @node.getblockheader(@block_hash)
    end

    it "should throw ConnectionError" do
      @node.client.mock_connection_error(true)
      expect { @node.getblockheader(@block_hash) }.to raise_error Node::ConnectionError
    end

    it "should throw MethodNotFoundError" do
      @node.client.mock_version(100000)
      expect { @node.getblockheader(@block_hash) }.to raise_error Node::MethodNotFoundError
    end

  end

  describe "poll!" do
    describe "on first run" do
      describe "Bitcoin Core" do
        after do
          test.shutdown()
        end

        before do
          stub_const("BitcoinClient::Error", BitcoinClientPython::Error)
          test.setup()
          @node = create(:node_python)
          @node.client.set_python_node(test.nodes[0])
          @node.client.generate(2)
          allow(Node).to receive("set_pool_tx_ids_fee_total_for_block!").and_return(nil)
        end

        it "should save the node" do
          @node.poll!
          expect(@node.id).not_to be_nil
        end

        it "should store the node version" do
          @node.poll!
          expect(@node.version).to be 199900
        end

        it "should get IBD status" do
          @node.poll!
          expect(@node.ibd).to eq(false)
        end

        it "should not store the latest block if in IBD" do
          allow(@node).to receive("ibd").and_return(true)
          @node.poll!
          expect(@node.block).to be_nil
        end

        # TODO: figure out how to put a regtest node in an IBD state
        # it "should store sync height if in IBD" do
        #   allow(@node).to receive("ibd").and_return(true)
        #   @node.poll!
        #   expect(@node.sync_height).to eq(2)
        # end

        it "should store the latest block if not in IBD" do
          @node.poll!
          expect(@node.block).not_to be_nil
          expect(@node.block.height).to eq(2)
          expect(@node.block.first_seen_by).to eq(@node)
        end

        it "should get mempool size" do
          @node.client.generate(100)
          @node.client.sendtoaddress(@node.client.getnewaddress(), 0.1)
          @node.poll!
          expect(@node.mempool_bytes).to be_within(2).of(141)
          expect(@node.mempool_count).to eq(1)
          expect(@node.mempool_max).to eq(300000000)
        end

      end

      describe "other clients" do
        before do
          @node = build(:node)
          @node.client.mock_ibd(true)
        end

        it "should parse 2.0.0 variant (e.g. Bcoin)" do
          @node.client.mock_version("2.0.0")
          @node.client.mock_client_type(:bcoin)
          @node.poll!
          expect(@node.version).to eq(2000000)
        end
      end
    end

    describe "on subsequent runs" do
      before do
        stub_const("BitcoinClient::Error", BitcoinClientPython::Error)
        test.setup()
        @node = create(:node_python)
        @node.client.set_python_node(test.nodes[0])
        @node.client.generate(2)
        expect(Node).to receive("set_pool_tx_ids_fee_total_for_block!").at_least(:once).and_return(nil)
        @node.poll! # stores the block and node entry
      end

      after do
        test.shutdown()
      end

      it "should get IBD status" do
        @node.poll!
        expect(@node.ibd).to eq(false)
      end

      it "should update to the latest block" do
        @node.poll!
        expect(@node.block.height).to equal(2)
      end

      it "should store size and number of transactions in block" do
        @node.client.generate(1)
        @node.poll!
        expect(@node.block.tx_count).to eq(1)
        expect(@node.block.size).to be_between(249, 250).inclusive
      end

      it "should store intermediate blocks" do
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

      it "should not store blocks during initial blockchain download" do
        @node.client.generate(2)
        allow(@node).to receive("ibd").and_return(true)
        @node.poll!
        @node.reload
        expect(@node.block).to be_nil
      end

      it "should not fetch parent blocks older than MINIMUM_BLOCK_HEIGHTS" do
        # Exit IBD, fetching all previous blocks would take forever, so don't:
        @node.client.generate(2)
        before = Block::MINIMUM_BLOCK_HEIGHTS[:btc]
        Block::MINIMUM_BLOCK_HEIGHTS[:btc] = 4
        @node.poll!
        Block::MINIMUM_BLOCK_HEIGHTS[:btc] = before
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

      it "should detect when node becomes unreachable" do
        test.shutdown()
        @node.poll!
        test.setup()
        expect(@node.unreachable_since).not_to be_nil
      end

      it "should detect when node becomes reachable" do
        @node.update unreachable_since: Time.now
        expect(@node.unreachable_since).not_to be_nil
        @node.poll!
        expect(@node.unreachable_since).to be_nil
      end
    end

    describe "Bitcoin Core 0.13.0" do
      before do
        allow(Node).to receive("set_pool_tx_ids_fee_total_for_block!").and_return(nil)
        @node = build(:node)
        @node.client.mock_version(130000)
        @node.client.mock_set_height(560177)
        @node.poll! # First poll stores the block and node entry
      end

      it "should get IBD status from verificationprogress" do
        @node.client.mock_ibd(true)
        @node.client.mock_set_height(976)
        @node.poll!
        expect(@node.ibd).to eq(true)

        @node.client.mock_ibd(false)
        @node.client.mock_set_height(560179)
        @node.poll!
        expect(@node.ibd).to eq(false)
      end

      it "should store intermediate blocks" do
        @node.client.mock_set_height(560179)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560179)
        expect(@node.block.parent).not_to be_nil
        expect(@node.block.parent.height).to equal(560178)
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(560177)
      end
    end

    describe "Bitcoin Core 0.10.3" do
      before do
        allow(Node).to receive("set_pool_tx_ids_fee_total_for_block!").and_return(nil)
        @node = build(:node)
        @node.client.mock_version(100300)
        @node.poll!
      end

      it "should get IBD status from verificationprogress" do
        @node.client.mock_ibd(true)
        expect(@node.ibd).to eq(false)
      end

      it "should use time from getblock instead of getblockchaininfo" do
        expect(@node.block.timestamp).to equal(1548498742)
      end

      it "should store intermediate blocks" do
        @node.client.mock_set_height(560179)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560179)
        expect(@node.block.parent).not_to be_nil
        expect(@node.block.parent.height).to equal(560178)
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(560177)
        expect(@node.block.parent.parent.timestamp).to equal(1548500251)
      end
    end

    describe "Bitcoin Core 0.8.6" do
      before do
        # Mock an additional more modern node:
        @node_ref = build(:node)
        @node_ref.client.mock_version(170100)
        @node_ref.poll!

        @node = build(:node)
        @node.client.mock_version(80600)
        @node.poll!
      end

      it "should use time from getblock instead of getblockchaininfo" do
        expect(@node.block.timestamp).to equal(1548498742)
      end

      it "should store intermediate blocks" do
        @node.client.mock_set_height(560179)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560179)
        expect(@node.block.parent).not_to be_nil
        expect(@node.block.parent.height).to equal(560178)
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(560177)
        expect(@node.block.parent.parent.timestamp).to equal(1548500251)
      end
    end

    describe "btcd" do
      before do
        allow(Node).to receive("set_pool_tx_ids_fee_total_for_block!").and_return(nil)
        @node = build(:node, client_type: :btcd)
        @node.client.mock_client_type(:btcd)
        @node.client.mock_version(120000)
        @node.poll!
      end

      it "should have correct data" do
        expect(@node.version).to equal(120000)
        expect(@node.block.height).to equal(560176)
      end

      it "should store intermediate blocks" do
        @node.client.mock_set_height(560178)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560178)
        expect(@node.block.parent.parent).not_to be_nil
      end

    end

    describe "Bitcoin ABC" do
      before do
        allow(Node).to receive("set_pool_tx_ids_fee_total_for_block!").and_return(nil)
        @node = build(:node, coin: :bch)
        @node.client.mock_coin(:bch)
        @node.client.mock_version(180500)
        @node.poll!
      end

      # TODO: add blocks to mock
      # it "should have correct data" do
      #   expect(@node.version).to equal(180500)
      #   expect(@node.block.timestamp).to equal(1548498742)
      # end
      #
      # it "should store intermediate blocks" do
      #   @node.client.mock_set_height(560178)
      #   @node.poll!
      #   @node.reload
      #   expect(@node.block.height).to equal(560178)
      #   expect(@node.block.parent.parent).not_to be_nil
      # end

    end

  end

  describe "poll_mirror!" do
    before do
      @node = build(:node_with_mirror)
      @node_without_mirror = build(:node)

      @node.client.mock_set_height(560177)
      @node_without_mirror.client.mock_set_height(560177)
      @node.mirror_client.mock_set_height(560177)

      @node.poll! # stores the block and node entry
    end

    it "node without mirror node should not have mirror_client" do
      n = build(:node)
      expect(n.mirror_client).to be_nil
    end

    # Polling the mirror node while it's performing an expensive operation
    # will slow down the regular polling operation.
    it "poll! should not poll mirror node" do
      @node.poll!
      expect(@node.mirror_block).to be_nil
    end

    it "poll_mirror! should poll mirror node" do
      @node.poll_mirror!
      expect(@node.mirror_block.height).to equal(560177)
    end

    it "poll_mirror! should do nothing if a node doesn't have a mirror" do
      @node_without_mirror.poll_mirror!
      expect(@node.mirror_block).to be_nil
    end
  end

  describe "Bitcoin Testnet" do
    before do
      @node = build(:node, coin: :tbtc)
      @node.client.mock_coin(:tbtc)
      @node.client.mock_version(180500)
      @node.poll!
    end

    # TODO: add mock data for testnet
    # it "should have correct data" do
    #   expect(@node.version).to equal(180500)
    #   expect(@node.block.timestamp).to equal(1548498742)
    # end
    #
    # it "should store intermediate blocks" do
    #   @node.client.mock_set_height(560178) # Mainnet based mock data
    #   @node.poll!
    #   @node.reload
    #   expect(@node.block.height).to equal(560178)
    #   expect(@node.block.parent.parent).not_to be_nil
    # end

  end

  describe "check_if_behind!" do
    after do
      test.shutdown()
    end

    before do
      # Two nodes at the same height
      test.setup(num_nodes: 2)
      @nodeA = create(:node_python)
      @nodeA.client.set_python_node(test.nodes[0])
      @nodeA.client.generate(2)

      @nodeB = create(:node_python)
      @nodeB.client.set_python_node(test.nodes[1])

      test.sync_blocks()
    end

    it "should detect if node A and B are at the same block" do
      expect(@nodeA.check_if_behind!(@nodeB)).to eq(nil)
    end

    describe "when behind" do
      let(:user) { create(:user) }

      before do
        allow(Node).to receive("set_pool_tx_ids_fee_total_for_block!").and_return(nil)

        test.disconnect_nodes(@nodeA.client, 1)
        assert_equal(0, @nodeA.client.getpeerinfo().count)

        @nodeB.client.generate(1)
        allow(Node).to receive(:bitcoin_core_by_version).and_return [@nodeA, @nodeB]

        Node.poll!
        @nodeA.peer_count = 1 # Bypass peer check in check_if_behind!
        @first_check = @nodeA.check_if_behind!(@nodeB)
        Timecop.freeze(Time.now + 15 * 60)
      end

      it "should be false if the difference is recent" do
        expect(@first_check).to eq(false)
      end

      it "should detect if node A is behind node B" do
        lag = @nodeA.check_if_behind!(@nodeB)
        expect(lag).not_to be_nil
        expect(lag.node_a).to eq(@nodeA)
        expect(lag.node_b).to eq(@nodeB)
      end

      it "should be nil if the node is unreachable" do
        @nodeA.update unreachable_since: Time.now
        expect(@nodeA.check_if_behind!(@nodeB)).to eq(nil)
      end

      it "should be nil if the node is in initial block download" do
        @nodeA.update ibd: true
        expect(@nodeA.check_if_behind!(@nodeB)).to eq(nil)
      end

      it "should be nil if other node is in initial block download" do
        @nodeB.update ibd: true
        expect(@nodeA.check_if_behind!(@nodeB)).to eq(nil)
      end

      it "should be nil if the node has no peers" do
        @nodeA.peer_count = 0
        expect(@nodeA.check_if_behind!(@nodeB)).to eq(nil)
      end

      it "should allow extra blocks for old nodes" do
        @nodeA.update version: 100300
        expect(@nodeA.check_if_behind!(@nodeB)).to eq(nil)
        @nodeB.client.generate(3)
        Node.poll!
        @nodeA.update peer_count: 1, version: 100300 # Undo override from poll
        expect(@nodeA.check_if_behind!(@nodeB)).not_to eq(nil)
      end

      it "should detect if bcoin node A is behind (core) node B" do
        @nodeA.update version: "2.0.0"
        @nodeA.update client_type: :bcoin

        lag = @nodeA.check_if_behind!(@nodeB)
        expect(lag).not_to be_nil
        expect(lag.node_a).to eq(@nodeA)
        expect(lag.node_b).to eq(@nodeB)
      end

      it "should allow extra blocks for btcd" do
        @nodeA.update client_type: :btcd, version: 120000
        expect(@nodeA.check_if_behind!(@nodeB)).to eq(nil)

        @nodeB.client.generate(2)
        @nodeA.update client_type: :core, version: 170000 # Poll should use core
        Node.poll!
        @nodeA.update peer_count: 1, client_type: :btcd, version: 120000
        expect(@nodeA.check_if_behind!(@nodeB)).not_to eq(nil)
      end

      it "should send an email to all users" do
        expect(User).to receive(:all).and_return [user]
        expect { @nodeA.check_if_behind!(@nodeB) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "should send email only once" do
        expect(User).to receive(:all).and_return [user]
        expect { @nodeA.check_if_behind!(@nodeB) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect { @nodeA.check_if_behind!(@nodeB) }.to change { ActionMailer::Base.deliveries.count }.by(0)
      end

    end
  end

  describe "check_versionbits!" do
    before do
      @node = build(:node)
      @node.client.mock_version(170100)
      @node.client.mock_set_height(560176)
      @node.poll!
      @node.client.mock_set_height(560177)
      @node.poll!
    end

    describe "during IBD" do
      before do
        @node.client.mock_ibd(true)
        @node.poll!
      end
      it "should do nothing" do
        @node.check_versionbits!
        expect(VersionBit.count).to eq(0)
      end
    end

    describe "below threshold" do
      it "should do nothing" do
        @node.check_versionbits!
        expect(VersionBit.count).to eq(0)
      end
    end

    describe "above threshold" do
      let(:user) { create(:user) }

      before do
        @node.client.mock_set_height(560178)
        @node.poll!
        @node.reload
      end

      it "should store a VersionBit entry" do
        @node.check_versionbits!
        expect(VersionBit.count).to eq(1)
        expect(VersionBit.first.bit).to eq(1)
        expect(VersionBit.first.activate).to eq(@node.block)
      end

      it "should send an email to all users" do
        expect(User).to receive(:all).and_return [user]
        expect { @node.check_versionbits! }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "should send email only once" do
        expect(User).to receive(:all).and_return [user]
        expect { @node.check_versionbits! }.to change { ActionMailer::Base.deliveries.count }.by(1)
        @node.client.mock_set_height(560179)
        @node.poll!
        @node.reload
        expect { @node.check_versionbits! }.to change { ActionMailer::Base.deliveries.count }.by(0)
      end

      it "should leave existing VersionBit entry alone" do
        expect(User).to receive(:all).and_return [user]

        @node.check_versionbits!
        @node.client.mock_set_height(560179)
        @node.poll!
        @node.reload
        expect(@node.block.height).to eq(560179)
        expect(@node.block.parent.height).to eq(560178)
        @node.check_versionbits!
        expect(VersionBit.count).to eq(1)
        expect(VersionBit.first.bit).to eq(1)
        expect(VersionBit.first.activate).to eq(@node.block.parent)
      end


      it "should mark VersionBit entry inactive if not signalled for" do
        @node.check_versionbits!

        @node.client.mock_set_height(560181)
        @node.poll!
        @node.reload
        @node.check_versionbits!
        expect(VersionBit.count).to eq(1)
        expect(VersionBit.first.deactivate).to eq(@node.block)

        @node.client.mock_set_height(560182)
        @node.poll!
        @node.reload
        @node.check_versionbits!
        expect(VersionBit.count).to eq(1)
        expect(VersionBit.first.deactivate).to eq(@node.block.parent)
      end

      it "should not mark VersionBit entry inactive too early" do
        @node.check_versionbits!

        @node.client.mock_set_height(560180)
        @node.poll!
        @node.reload
        @node.check_versionbits!
        expect(VersionBit.count).to eq(1)
        expect(VersionBit.first.deactivate).to be_nil
      end
    end
  end

  # TODO: move to Block tests
  describe "blockfind_ancestors!" do
    before do
      @node = build(:node)
      expect(Block.minimum(:height)).to equal(nil)
      @node.client.mock_set_height(560179)
      @node.poll!
      @node.reload
      expect(@node.block.height).to equal(560179)
      expect(Block.minimum(:height)).to equal(560176)
    end

    it "should not fetch parents before height 560176" do
      @node.block.find_ancestors!(@node, false, true)
      expect(Block.minimum(:height)).to equal(560176)
    end

    it "with block argument should fetch parents beyond the oldest block" do
      @node.client.mock_set_height(560182)
      @node.poll!
      @node.reload
      expect(@node.block.height).to equal(560182)
      expect(Block.count).to equal(7)

      @node.block.find_ancestors!(@node, false, true, 560176)
      expect(Block.count).to equal(7)
      expect(Block.minimum(:height)).to equal(560176)
    end
  end

  describe "getrawtransaction" do
    before do
      @tx_id = "74e243e5425edfce9486e26aa6449e56c68351210e8edc1fe81ddcdc8d478085"
      @node = build(:node, txindex: true)
      @node.client.mock_version(170100)
      @node.client.mock_set_height(560178)
      @node.poll!
    end

    it "should call getrawtransaction" do
      expect(@node.getrawtransaction(@tx_id)).to eq("010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff5303368c081a4d696e656420627920416e74506f6f6c633e007902205c4c4eadfabe6d6dd1950c951397395896a26405b01c17c50070f4a287b029b377eae4148bc9133f04000000000000005201000079650000ffffffff03478b704b000000001976a914edf10a7fac6b32e24daa5305c723f3de58db1bc888ac0000000000000000266a24aa21a9ed8d4ee584d2bd2483c525df85654a2fcfa9125638dd6fe56405a0590b3da0347800000000000000002952534b424c4f434b3ac6695c75ffa1f93f9237c6997abd16c988a3b442545478f81fd49d9af1b2ce9a0120000000000000000000000000000000000000000000000000000000000000000000000000")
    end

    it "should handle tx not found" do
      expect { @node.getrawtransaction(@tx_id.reverse) }.to raise_error Node::TxNotFoundError
    end

  end

  describe "class" do
    describe "set_pool_tx_ids_fee_total_for_block!" do
      before do
        @block = create(:block, block_hash: "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377")
        @node = create(:node, coin: :btc, block: @block, version: 160000)

        @modernNode = create(:node, coin: :btc, txindex: true)
        @modernNode.client.mock_set_height(560178)
        @modernNode.poll!

        expect(Node).to receive(:first_newer_than).with(:btc, 160000, :core).and_return @modernNode
      end

      it "should fetch the block" do
        expect(@modernNode.client).to receive("getblock").and_call_original
        Node.set_pool_tx_ids_fee_total_for_block!(:btc, @block)
      end


      it "should not fetch the block if getblock is cached" do
        expect(@modernNode.client).not_to receive("getblock")
        Node.set_pool_tx_ids_fee_total_for_block!(:btc, @block, {"height": 1 ,"tx" => ["74e243e5425edfce9486e26aa6449e56c68351210e8edc1fe81ddcdc8d478085"]})
      end

      it "should call getrawtransaction on the coinbase" do
        expect(@modernNode.client).to receive("getrawtransaction").and_call_original
        Node.set_pool_tx_ids_fee_total_for_block!(:btc, @block)
      end

      it "should pass getrawtransaction output to pool_from_coinbase_tx" do
        expect(Block).to receive(:pool_from_coinbase_tx)
        Node.set_pool_tx_ids_fee_total_for_block!(:btc, @block)
      end

      it "should calculate the total fee" do
        Node.set_pool_tx_ids_fee_total_for_block!(:btc, @block)
        expect(@block.total_fee).to eq(0.5)
      end
    end

    describe "poll!" do
      it "should call poll! on all nodes, followed by check_laggards!, check_chaintips! and check_versionbits!" do
        node1 = create(:node_with_block, coin: :btc, version: 170000)
        node2 = create(:node_with_block, coin: :btc, version: 160000)
        node3 = create(:node_with_block, coin: :bch)

        expect(Node).to receive(:check_laggards!)

        expect(Node).to receive(:check_chaintips!).with(:btc)
        expect(Node).to receive(:check_chaintips!).with(:tbtc)
        expect(Node).to receive(:check_chaintips!).with(:bch)

        expect(Node).to receive(:bitcoin_core_by_version).and_wrap_original {|relation|
          relation.call.each {|node|
            expect(node).to receive(:poll!)
          }
        }
        expect(Node).to receive(:bitcoin_core_by_version).and_wrap_original {|relation|
          relation.call.each {|node|
            if node.version ==  170000
              expect(node).to receive(:check_versionbits!)
            end
          }
        }

        expect(Node).to receive(:bch_by_version).once().and_wrap_original {|relation|
          relation.call.each {|node|
            expect(node).to receive(:poll!)
          }
        }

        Node.poll!
      end
    end

    describe "poll_repeat!" do
      it "should call poll!" do
        expect(Node).to receive(:poll!).with({repeat: true, coins: ["BTC"]})

        Node.poll_repeat!({coins: ["BTC"]})
      end
    end

    describe "restore_mirror" do

      after do
        test.shutdown()
      end

      before do
        test.setup()
        allow(Node).to receive("set_pool_tx_ids_fee_total_for_block!").and_return(nil)
        @node = create(:node_python_with_mirror)
        @node.client.set_python_node(test.nodes[0])
        @node.mirror_client.set_python_node(test.nodes[0]) # use same node for mirror
        @node.mirror_client.generate(2)
        @block_hash = @node.client.getbestblockhash()
        @node.poll_mirror!
        @node.mirror_client.invalidateblock(@block_hash)
      end

      it "should restore network and reconsider blocks" do
        expect(@node.mirror_client).to receive("setnetworkactive").with(true)
        expect(@node.mirror_client).to receive("reconsiderblock").with(@block_hash)
        @node.restore_mirror
      end

    end

    describe "inflation_check_repeat!" do
      before do
        @node = create(:node_with_mirror)
        @node.mirror_client.mock_set_height(560176)
      end

      it "should check inflation" do
        expect(InflatedBlock).to receive(:check_inflation!).with({coin: :btc, max: 20})
        Node.inflation_check_repeat!({coins: ["BTC"]})
      end
    end

    describe "heavy_checks_repeat!" do
      before do
        @node = create(:node_with_mirror)
        @node.mirror_client.mock_set_height(560176)
        allow(Node).to receive(:coin_by_version).with(:btc).and_return [@node] # Preserve mirror client instance
        allow(Node).to receive(:destroy_if_requested).and_return true
        allow(LightningTransaction).to receive(:check!).and_return true
        allow(LightningTransaction).to receive(:check_public_channels!).and_return true
        allow(Block).to receive(:find_missing).and_return true
        allow(StaleCandidate).to receive(:prime_cache).and_return true
      end

      it "should run Lightning checks, on BTC only" do
        expect(LightningTransaction).to receive(:check!).with({coin: :btc, max: 1000})
        expect(LightningTransaction).not_to receive(:check!).with({coin: :tbtc, max: 1000})

        Node.heavy_checks_repeat!({coins: ["BTC", "TBTC"]})
      end

      it "should call check_public_channels!" do
        expect(LightningTransaction).to receive(:check_public_channels!)
        Node.heavy_checks_repeat!({coins: ["BTC"]})
      end

      it "should call match_missing_pools!" do
        expect(Block).to receive(:match_missing_pools!).with(:btc, 3)
        Node.heavy_checks_repeat!({coins: ["BTC"]})
      end

      it "should call process_stale_candidates" do
        expect(StaleCandidate).to receive(:process!).with(:btc)
        Node.heavy_checks_repeat!({coins: ["BTC"]})
      end

      it "should call find_missing" do
        expect(Block).to receive(:find_missing).with(:btc, 40000, 20)
        Node.heavy_checks_repeat!({coins: ["BTC"]})
      end

      it "should call process_templates" do
        expect(Block).to receive(:process_templates!).with(:btc)
        Node.heavy_checks_repeat!({coins: ["BTC"]})
      end

    end

    describe "getblocktemplate_repeat!" do
      before do
        @node = create(:node)
        allow(Node).to receive(:coin_by_version).with(:btc).and_return [@node] # Preserve mirror client instance
      end

      it "should call getblocktemplate" do
        expect(Node).to receive(:getblocktemplate!).with(:btc)

        Node.getblocktemplate_repeat!({coins: ["BTC"]})
      end
    end

    describe "check_laggards!" do
      before do
        @A = build(:node)
        @A.client.mock_version(170100)
        @A.poll!

        @B = build(:node)
        @B.client.mock_version(100300)
        @B.poll!
      end

      it "should call check_if_behind! against the newest node" do
        expect(Node).to receive(:bitcoin_core_by_version).and_wrap_original {|relation|
          relation.call.each {|record|
            if record.id == @A.id
              expect(record).not_to receive(:check_if_behind!)
            else
              expect(record).to receive(:check_if_behind!)
            end
          }
        }
        Node.check_laggards!
      end
    end

    describe "check_chaintips!" do
      before do
        @A = build(:node)
        @A.client.mock_version(170100)
        @A.poll!

        @B = build(:node)
        @B.client.mock_version(100300)
        @B.poll!
      end

      it "should call check! on Chaintip and on InvalidBlock" do
        expect(Chaintip).to receive(:check!).with(:btc, [@A,@B])
        expect(InvalidBlock).to receive(:check!)
        Node.check_chaintips!(:btc)
      end
    end

    describe "fetch_ancestors!" do
      before do
        @A = build(:node)
        @A.client.mock_version(170100)
        @A.client.mock_set_height(560178)
        @A.poll!

        @B = build(:node)
        @B.client.mock_version(100300)
        @B.client.mock_set_height(560178)
        @B.poll!
      end

      it "should call find_ancestors! with the newest node" do
        expect(Node).to receive(:bitcoin_core_by_version).and_wrap_original {|relation|
          relation.call.each {|record|
            if record.id == @A.id
              expect(record.block).to receive(:find_ancestors!)
            else
              expect(record.block).not_to receive(:find_ancestors!)
            end
          }
        }
        Node.fetch_ancestors!(560176)
      end
    end

    describe "first_with_txindex" do
      before do
        @A = build(:node)
        @A.client.mock_version(170100)
        @A.client.mock_set_height(560178)
        @A.poll!

        @B = build(:node, txindex: true)
        @B.client.mock_version(100300)
        @B.client.mock_set_height(560178)
        @B.poll!
      end

      it "should be called with an known coin" do
        expect { Node.first_with_txindex(:bbbbbbtc) }.to raise_error Node::InvalidCoinError
      end

      it "should throw if no node has txindex" do
        @B.update txindex: false
        expect { Node.first_with_txindex(:btc) }.to raise_error Node::NoTxIndexError
      end

      it "should return node" do
        expect(Node.first_with_txindex(:btc)).to eq(@B)
      end

    end

    describe "getrawtransaction" do
      before do
        @tx_id = "74e243e5425edfce9486e26aa6449e56c68351210e8edc1fe81ddcdc8d478085"
        @A = build(:node, txindex: true)
        @A.client.mock_version(170100)
        @A.client.mock_set_height(560178)
        @A.poll!
      end

      it "should call getrawtransaction on a node with txindex" do
        expect(Node).to receive(:first_with_txindex).with(:btc).and_return @A
        expect(@A).to receive(:getrawtransaction).with(@tx_id, false, nil)
        Node.getrawtransaction(@tx_id, :btc)
      end

    end
  end
end
