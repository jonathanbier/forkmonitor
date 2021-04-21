require 'rails_helper'
require "bitcoind_helper"

RSpec.describe Chaintip, type: :model do
  let(:test) { TestWrapper.new() }

  def setup_python_nodes
    @use_python_nodes = true

    stub_const("BitcoinClient::Error", BitcoinClientPython::Error)
    stub_const("BitcoinClient::ConnectionError", BitcoinClientPython::ConnectionError)
    # The current commit of Bitcoin Core has wallet taproot descriptor support,
    # even when taproot is not active. We take advantage of this by creating
    # a transaction in the non-taproot wallet and then calling abandontransaction.
    #
    # TOOD: figure out how to get the "send" RPC to work ('send' is a reserved
    # keyword in Ruby and Python and this seems to confuse the wrapper)
    #
    # Once a release with Taproot support is available, it's best to use that
    # for the second node, so that this test still works when Taproot deployment
    # is burried (at which point vbparams won't work).
    test.setup(num_nodes: 3, extra_args: [[],["-vbparams=taproot:1:1"],["-vbparams=taproot:1:1"]])
    @nodeA = create(:node_python) # Taproot enabled
    @nodeA.client.set_python_node(test.nodes[0])
    @nodeB = create(:node_python) # Taproot disabled
    @nodeB.client.set_python_node(test.nodes[1])
    @nodeC = create(:node_python) # Taproot disabled (doesn't really matter)
    @nodeC.client.set_python_node(test.nodes[2])

    # Disconnect Node C so we can give it a an independent chain
    @nodeC.client.setnetworkactive(false)
    test.disconnect_nodes(0, 2)
    test.disconnect_nodes(1, 2)

    @nodeA.client.createwallet()
    @nodeB.client.createwallet(blank: true)
    @nodeB.client.importdescriptors([
      {"desc": "tr(tprv8ZgxMBicQKsPeNLUGrbv3b7qhUk1LQJZAGMuk9gVuKh9sd4BWGp1eMsehUni6qGb8bjkdwBxCbgNGdh2bYGACK5C5dRTaif9KBKGVnSezxV/0/*)#c8796lse", "active": true, "internal": false, "timestamp": "now", "range": 10},
      {"desc": "tr(tprv8ZgxMBicQKsPeNLUGrbv3b7qhUk1LQJZAGMuk9gVuKh9sd4BWGp1eMsehUni6qGb8bjkdwBxCbgNGdh2bYGACK5C5dRTaif9KBKGVnSezxV/1/*)#fnmy82qp", "active": true, "internal": true, "timestamp": "now", "range": 10}
    ])
    @addr1 = @nodeB.client.getnewaddress()
    @addr2 = @nodeB.client.getnewaddress()
    @r_addr = @nodeA.client.getnewaddress()

    @nodeA.client.generatetoaddress(2, @r_addr)
    test.sync_blocks([@nodeA.client, @nodeB.client])

    @nodeA.poll!
    @nodeA.reload
    assert_equal(@nodeA.block.height, 2)
    expect(@nodeA.block.parent).not_to be_nil
    assert_equal(@nodeA.block.parent.height, 1)
    assert_equal(Chaintip.count, 0)

    @nodeB.poll!
    @nodeB.reload
    assert_equal(@nodeB.block.height, 2)
    assert_equal(@nodeB.block.parent.height, 1)
    assert_equal(Chaintip.count, 0)

    @nodeC.client.createwallet()
    @addr3 = @nodeC.client.getnewaddress()
    @nodeC.client.generatetoaddress(3, @addr3) # longer chain than A and B, so it won't validate those blocks
    # Node C intentionally remains disconnected from A and B
  end

  after do
    if @use_python_nodes
      test.shutdown()
    end
  end

  describe "process_active!" do
    before do
      setup_python_nodes()
    end

    it "should create fresh chaintip for a new node" do
      tip = Chaintip.process_active!(@nodeA, @nodeA.block)
      expect(tip.id).not_to be_nil
    end

    it "should not update existing chaintip entry if the block unchanged" do
      tip_before = Chaintip.process_active!(@nodeA, @nodeA.block)
      @nodeA.poll!
      tip_after = Chaintip.process_active!(@nodeA, @nodeA.block)
      expect(tip_before).to eq(tip_after)
    end

    it "should update existing chaintip entry if the block changed" do
      tip_before = Chaintip.process_active!(@nodeA, @nodeA.block)
      @nodeA.client.generate(1)
      @nodeA.poll!
      tip_after = Chaintip.process_active!(@nodeA, @nodeA.block)
      expect(tip_before.id).to eq(tip_after.id)
      expect(tip_after.block).to eq(@nodeA.block)
    end

    it "should create fresh chaintip for the different node" do
      tip_A = Chaintip.process_active!(@nodeA, @nodeA.block)
      tip_B = Chaintip.process_active!(@nodeB, @nodeB.block)
      expect(tip_A).not_to eq(tip_B)
    end

  end

  describe "nodes_for_identical_chaintips / process_active!" do
    let(:block1) { create(:block) }
    let(:block2) { create(:block, parent: block1) }
    let(:nodeA) { create(:node, block: block1) }
    let(:nodeB) { create(:node) }
    let(:nodeC) { create(:node) }
    let(:chaintip1) { create(:chaintip, block: block1, node: nodeA) }
    let(:chaintip2) { create(:chaintip, block: block1, node: nodeB) }

    it "should show all nodes at height of active chaintip" do
      setup_python_nodes()
      @tipA = Chaintip.process_active!(@nodeA, @nodeA.block)
      @tipB = Chaintip.process_active!(@nodeB, @nodeB.block)
      assert_equal 2, @tipA.nodes_for_identical_chaintips.count
      assert_equal [@nodeA, @nodeB], @tipA.nodes_for_identical_chaintips
    end

    it "should only support the active chaintip" do
      chaintip1.update status: "invalid"
      assert_nil chaintip1.nodes_for_identical_chaintips
      assert_nil chaintip1.nodes_for_identical_chaintips
    end

  end

  describe "process_valid_headers!" do
    before do
      setup_python_nodes()
    end

    it "should do nothing if we already know the block" do
      block = Block.create(coin: :btc, block_hash: "1234", height: 5)
      expect(Block).not_to receive(:create_headers_only)
      Chaintip.process_valid_headers!(@nodeA, {"hash" => "1234", "height" => 5}, block)
    end

    it "should create headers_only block entry" do
      expect(Block).to receive(:create_headers_only)
      Chaintip.process_valid_headers!(@nodeA, {"hash" => "1234", "height" => 5}, nil)
    end
  end

  describe "match_parent!" do
    let(:nodeA) { create(:node) }
    let(:nodeB) { create(:node) }
    let(:block1) { create(:block) }
    let(:block2) { create(:block, parent: block1) }
    let(:block3) { create(:block, parent: block2) }
    let(:chaintip1) { create(:chaintip, block: block1, node: nodeA) }
    let(:chaintip2) { create(:chaintip, block: block1, node: nodeB) }

    it "should do nothing if all nodes are the same height" do
      chaintip2.match_parent!(nodeB)
      assert_nil chaintip2.parent_chaintip
    end

    describe "when another chaintip is longer" do
      before do
        chaintip1.update block: block2
      end

      it "should mark longer chain as parent" do
        chaintip2.match_parent!(nodeB)
        assert_equal(chaintip2.parent_chaintip, chaintip1)
      end


      it "should mark even longer chain as parent" do
        chaintip1.update block: block3
        chaintip2.match_parent!(nodeB)
        assert_equal(chaintip2.parent_chaintip, chaintip1)
      end

      it "should not mark invalid chain as parent" do
        # Node B considers block b invalid:
        chaintip3 = create(:chaintip, block: block2, node: nodeB, status: "invalid")

        chaintip2.match_parent!(nodeB)
        assert_nil(chaintip2.parent_chaintip)
      end

      it "should not mark invalid chain as parent, based on block marked invalid" do
        # Node B considers block b invalid:
        block2.update marked_invalid_by: block2.marked_invalid_by | [nodeB.id]

        chaintip2.match_parent!(nodeB)
        assert_nil(chaintip2.parent_chaintip)
      end
    end

  end

  describe "check_parent!" do

    let(:nodeA) { create(:node) }
    let(:nodeB) { create(:node) }
    let(:block1) { create(:block) }
    let(:block2) { create(:block, parent: block1) }
    let(:block3) { create(:block, parent: block2) }
    let(:chaintip1) { create(:chaintip, block: block1, node: nodeA) }
    let(:chaintip2) { create(:chaintip, block: block1, node: nodeB) }

    describe "when another chaintip is longer" do

      before do
        chaintip1.update block: block2
      end

      it "should unmark parent if it later considers it invalid" do
        chaintip2.update parent_chaintip: chaintip1 # For example via match_children!

        chaintip3 = create(:chaintip, block: block2, node: nodeB, status: "invalid")
        chaintip2.check_parent!(nodeB)
        assert_nil(chaintip2.parent_chaintip)
      end

    end

  end

  describe "match_children!" do
    let(:nodeA) { create(:node) }
    let(:nodeB) { create(:node) }
    let(:block1) { create(:block) }
    let(:block2) { create(:block, parent: block1) }
    let(:chaintip1) { create(:chaintip, block: block1, node: nodeA) }
    let(:chaintip2) { create(:chaintip, block: block1, node: nodeB) }

    it "should do nothing if all nodes are the same height" do
      chaintip1.match_children!(nodeB)
      assert_nil chaintip1.parent_chaintip
    end

    describe "when another chaintip is shorter" do
      before do
        chaintip1.update block: block2
        chaintip2 # lazy load
      end

      it "should mark itself as the parent" do
        chaintip1.match_children!(nodeB)
        chaintip2.reload
        assert_equal(chaintip2.parent_chaintip, chaintip1)
      end

      it "should not mark itself as parent if the other node considers it invalid" do
        # Node B considers block b invalid:
        chaintip3 = create(:chaintip, block: block2, node: nodeB, status: "invalid")
        chaintip1.match_children!(nodeB)
        chaintip2.reload
        assert_nil(chaintip2.parent_chaintip)
      end
    end
  end

  describe "check!" do
    before do
      setup_python_nodes()
    end
    describe "one node in IBD" do
      it "should do nothing" do
        @nodeA.update ibd: true
        Chaintip.check!(:btc, [@nodeA])
        expect(@nodeA.chaintips.count).to eq(0)
      end
    end

    describe "only an active chaintip" do
      it "should add a chaintip entry" do
        expect(@nodeA.chaintips.count).to eq(0)
        Chaintip.check!(:btc, [@nodeA])
        expect(@nodeA.chaintips.count).to eq(1)
        expect(@nodeA.chaintips.first.block.height).to eq(2)
      end
    end

    describe "one active and one valid-fork chaintip" do
      before do
        test.disconnect_nodes(0, 1)
        assert_equal(0, @nodeA.client.getpeerinfo().count)

        @nodeA.client.generate(2) # this will be a valid-fork after reorg
        @nodeB.client.generate(3) # reorg to this upon reconnect
        @nodeA.poll!
        @nodeB.poll!
        test.connect_nodes(0, 1)
        test.sync_blocks([@nodeA.client,@nodeB.client])
      end

      it "should add chaintip entries" do
        Chaintip.check!(:btc, [@nodeA])
        expect(@nodeA.chaintips.count).to eq(2)
        expect(@nodeA.chaintips.last.status).to eq("valid-fork")
      end

      it "should add the valid fork blocks up to the common ancenstor" do
        Chaintip.check!(:btc, [@nodeA])
        @nodeA.reload
        split_block = Block.find_by(height: 2)
        fork_tip = @nodeA.block
        expect(fork_tip.height).to eq(4)
        expect(fork_tip).not_to be_nil
        expect(fork_tip.parent).not_to be_nil
        expect(fork_tip.parent.height).to eq(3)
        expect(fork_tip.parent.parent).to eq(split_block)
      end

      it "should ignore forks more than 1000 blocks ago" do
        # 10 on regtest
        test.disconnect_nodes(0, 1)
        assert_equal(0, @nodeA.client.getpeerinfo().count)

        @nodeA.client.generate(11) # this will be a valid-fork after reorg
        @nodeB.client.generate(12) # reorg to this upon reconnect
        @nodeA.poll!
        @nodeB.poll!
        test.connect_nodes(0, 1)

        Chaintip.check!(:btc, [@nodeA])
        expect(@nodeA.chaintips.count).to eq(2)
      end
    end

    describe "nodeA ahead of nodeB" do
      before do
        @nodeA.client.generate(2)
        @nodeA.poll!
        @nodeB.poll!
        # Disconnect nodes and produce one more block for A
        test.disconnect_nodes(0, 1)
        assert_equal(0, @nodeA.client.getpeerinfo().count)
        @nodeA.client.generate(1)
        @nodeA.poll!
        Chaintip.check!(:btc, [@nodeA, @nodeB])
      end

      it "should match parent block" do
        tip_A = @nodeA.chaintips.where(status: "active").first
        tip_B = @nodeB.chaintips.where(status: "active").first
        expect(tip_A).not_to be(tip_B)
        expect(tip_B.parent_chaintip).to eq(tip_A)
      end
    end

    describe "invalid chaintip" do
      before do
        # Reach coinbase maturity
        @nodeA.client.generatetoaddress(99, @r_addr)

        # Fund a taproot address and mine it
        @nodeA.client.sendtoaddress(@addr1, 1)
        @nodeA.client.generate(1)
        test.sync_blocks([@nodeA.client,@nodeB.client])

        # Spend from taproot address (this node has taproot disabled, so it won't broadcast)
        tx_id = @nodeB.client.sendtoaddress(@r_addr, 0.1)
        tx_hex = @nodeB.client.gettransaction(tx_id)["hex"]
        @nodeB.client.abandontransaction(tx_id)

        txs = @nodeB.client.listtransactions()
        assert_equal(txs[1]['txid'], tx_id)
        assert_equal(txs[1]['abandoned'], true)

        mempool_tap = @nodeA.client.testmempoolaccept([tx_hex])[0]
        mempool_no_tap = @nodeB.client.testmempoolaccept([tx_hex])[0]
        expect(mempool_tap['allowed']).to eq(true)
        expect(mempool_no_tap['allowed']).to eq(false)
        expect(mempool_no_tap['reject-reason']).to eq("bad-txns-nonstandard-inputs")

        # Cripple transaction so that it's invalid under taproot rules
        if tx_hex[-20] == "0" then
          tx_hex[-20] = "f"
        else
          tx_hex[-20] = "0"
        end

        mempool_broken_tap = @nodeA.client.testmempoolaccept([tx_hex])[0]
        mempool_broken_no_tap = @nodeB.client.testmempoolaccept([tx_hex])[0]

        expect(mempool_broken_no_tap['allowed']).to eq(false)
        expect(mempool_broken_no_tap['reject-reason']).to eq('bad-txns-nonstandard-inputs')

        expect(mempool_broken_tap['allowed']).to eq(false)
        expect(mempool_broken_tap['reject-reason']).to eq('non-mandatory-script-verify-flag (Invalid Schnorr signature)')

        # @nodeA.client.sendrawtransaction(tx_hex)
        block_hex = test.createtaprootblock([tx_hex])
        @nodeB.client.submitblock(block_hex)
        sleep(1)

        @disputed_block_hash = @nodeB.client.getbestblockhash
      end

      describe "not in our db" do
        before do
          # Don't poll node B, so our DB won't contain the disputed block
          @nodeA.poll!
        end

        it "should store the block" do
          Chaintip.check!(:btc, [@nodeA])
          block = Block.find_by(block_hash: @disputed_block_hash)
          expect(block).not_to be_nil
        end

        it "should mark the block as invalid" do
          Chaintip.check!(:btc, [@nodeA])
          block = Block.find_by(block_hash: @disputed_block_hash)
          expect(block).not_to be_nil
          expect(block.marked_invalid_by).to include(@nodeA.id)
        end

        it "should store invalid tip" do
          Chaintip.check!(:btc, [@nodeA])
          expect(@nodeA.chaintips.where(status: "invalid").count).to eq(1)
        end
      end

      describe "in our db" do
        before do
          @nodeA.poll!
          @nodeB.poll!
        end

        it "should mark the block as invalid" do
          Chaintip.check!(:btc, [@nodeA])
          block = Block.find_by(block_hash: @disputed_block_hash)
          expect(block).not_to be_nil
          expect(block.marked_invalid_by).to include(@nodeA.id)
        end

        it "should store invalid tip" do
          Chaintip.check!(:btc, [@nodeA])
          expect(@nodeA.chaintips.where(status: "invalid").count).to eq(1)
        end

        it "should be nil if the node is unreachable" do
          @nodeA.client.mock_connection_error(true)
          @nodeA.poll!
          Chaintip.check!(:btc, [@nodeA])
          expect(@nodeA.chaintips.count).to eq(0)
        end

      end
    end
  end
end
