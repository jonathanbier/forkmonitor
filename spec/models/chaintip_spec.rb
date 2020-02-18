require 'rails_helper'
require "bitcoind_helper"

def setup_python_nodes
  @use_python_nodes = true

  stub_const("BitcoinClient::Error", BitcoinClientPython::Error)
  test.setup(num_nodes: 2)
  @nodeA = create(:node_python)
  @nodeA.client.set_python_node(test.nodes[0])
  @nodeB = create(:node_python)
  @nodeB.client.set_python_node(test.nodes[1])

  @nodeA.client.generate(2)
  test.sync_blocks()

  @nodeA.poll!
  @nodeA.reload
  assert_equal(@nodeA.block.height, 2)
  assert_equal(@nodeA.block.parent.height, 1)
  assert_equal(Chaintip.count, 0)

  @nodeB.poll!
  @nodeB.reload
  assert_equal(@nodeB.block.height, 2)
  assert_equal(@nodeB.block.parent.height, 1)
  assert_equal(Chaintip.count, 0)
end

RSpec.describe Chaintip, type: :model do
  let(:test) { TestWrapper.new() }

  after do
    if @use_python_nodes
      test.shutdown()
    end
  end

  describe "process_active!" do
    before do
      setup_python_nodes()
    end

    it "should chreate fresh chaintip for a new node" do
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

    it "should chreate fresh chaintip for the different node" do
      tip_A = Chaintip.process_active!(@nodeA, @nodeA.block)
      tip_B = Chaintip.process_active!(@nodeB, @nodeB.block)
      expect(tip_A).not_to eq(tip_B)
    end

    it "should match parent block" do
      tip_A = Chaintip.process_active!(@nodeA, @nodeA.block)
      tip_B = Chaintip.process_active!(@nodeB, @nodeB.block.parent)
      expect(tip_A).not_to be(tip_B)
      expect(tip_B.parent_chaintip).to eq(tip_A)
    end

    it "should match child block" do
      tip_A = Chaintip.process_active!(@nodeA, @nodeA.block.parent)
      tip_B = Chaintip.process_active!(@nodeB, @nodeB.block)
      tip_A.reload
      expect(tip_A).not_to be(tip_B)
      expect(tip_A.parent_chaintip).to eq(tip_B)
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

    it "should include parent blocks in chaintip" do
      chaintip1.update block: block2
      nodeA.update block: block2
      nodeB.update block: block1
      Chaintip.process_active!(nodeB, block1)
      assert_equal 2, chaintip1.nodes_for_identical_chaintips.count
      assert_equal [nodeA, nodeB], chaintip1.nodes_for_identical_chaintips
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

      it "should unmark parent if it later considers it invalid" do
        chaintip2.update parent_chaintip: chaintip1 # For example via match_children!

        chaintip3 = create(:chaintip, block: block2, node: nodeB, status: "invalid")
        chaintip2.match_parent!(nodeB)
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
end
