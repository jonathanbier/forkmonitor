require "rails_helper"

RSpec.describe Node, :type => :model do
  describe "version" do
    it "should be set" do
      node = create(:node_with_block)
      expect(node.version).not_to eq(0)
    end
  end

  describe "poll!" do
    describe "on first run" do
      before do
        @node = build(:node)
        @node.poll!
      end

      it "should save the node" do
        expect(@node.id).not_to be_nil
      end

      it "should store the node version" do
        expect(@node.version).to eq(170100)
      end

      it "should store the latest block" do
        expect(@node.block).not_to be_nil
        expect(@node.block.height).to equal(560176)
      end
    end

    describe "on subsequent runs" do
      before do
        @node = build(:node)
        @node.poll! # stores the block and node entry
        @node.client.mock_set_height(560177)
      end

      it "should update to the latest block" do
        @node.poll!
        expect(@node.block.height).to equal(560177)
      end

      it "should store intermediate blocks" do
        @node.client.mock_set_height(560179)
        @node.poll!
        expect(@node.block.height).to equal(560179)
        expect(@node.block.parent).not_to be_nil
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(560177)
      end

      it "should not store intermediate blocks for altcoin nodes" do
        @node.update coin: "BCH"
        @node.client.mock_set_height(560178)
        @node.poll!
        expect(@node.block.height).to equal(560178)
        expect(@node.block.parent).to be_nil
      end

      it "should detect when node becomes unreachable" do
        @node.client.mock_unreachable
        @node.poll!
        expect(@node.unreachable_since).not_to be_nil
      end

      it "should detect when node becomes reachable" do
        @node.client.mock_unreachable
        @node.poll!
        @node.client.mock_reachable
        @node.poll!
        expect(@node.unreachable_since).to be_nil
      end
    end
  end

  describe "class" do
    describe "poll!" do
      it "should call poll! on all nodes" do
        node = create(:node_with_block)
        expect(Node).to receive(:all).and_return [node]
        expect(node).to receive(:poll!)
        Node.poll!
      end
    end
  end
end
