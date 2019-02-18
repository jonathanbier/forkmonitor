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
      end

      it "should save the node" do
        @node.poll!
        expect(@node.id).not_to be_nil
      end

      it "should store the node version" do
        @node.poll!
        expect(@node.version).to eq(170100)
      end

      it "should store the latest block" do
        @node.poll!
        expect(@node.block).not_to be_nil
        expect(@node.block.height).to equal(560176)
      end

      it "should get IBD status, if true" do
        @node.client.mock_ibd(true)
        @node.client.mock_set_height(976)

        @node.poll!
        expect(@node.ibd).to eq(true)
      end

      it "should get IBD status, if false" do
        @node.client.mock_ibd(false)
        @node.client.mock_set_height(560179)

        @node.poll!
        expect(@node.ibd).to eq(false)
      end
    end

    describe "on subsequent runs" do
      before do
        @node = build(:node)
        @node.client.mock_ibd(false)
        @node.client.mock_set_height(560177)

        @node.poll! # stores the block and node entry
      end

      it "should get IBD status" do
        expect(@node.ibd).to eq(false)

        @node.client.mock_set_height(976)
        @node.client.mock_ibd(true)
        @node.poll!
        expect(@node.ibd).to eq(true)
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
        expect(@node.block.parent.height).to equal(560178)
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(560177)
      end

      it "should not store intermediate blocks for altcoin nodes" do
        @node.update coin: "BCH"
        @node.client.mock_set_height(560178)
        @node.poll!
        expect(@node.block.height).to equal(560178)
        expect(@node.block.parent.parent).to be_nil
      end

      it "should not store intermediate blocks during initial blockchain download" do
        @node.client.mock_ibd(true)
        @node.client.mock_set_height(976)
        @node.poll!
        expect(@node.block.height).to equal(976)
        expect(@node.block.parent).to be_nil
      end

      it "should not store intermediate blocks when existing initial blockchain download" do
        @node.client.mock_ibd(true)
        @node.client.mock_set_height(976)
        @node.poll!

        # Exit IBD, fetching all previous blocks would take forever, so don't:
        @node.client.mock_ibd(false)
        @node.client.mock_set_height(560177)
        @node.poll!
        expect(@node.block.height).to equal(560177)
        expect(@node.block.parent).to be_nil

        # Two blocks later, now it should fetch intermediate blocks:
        @node.client.mock_set_height(560179)
        @node.poll!
        expect(@node.block.height).to equal(560179)
        expect(@node.block.parent.height).to equal(560178)
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

    describe "Bitcoin Core 0.13.0" do
      before do
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
        expect(@node.block.height).to equal(560179)
        expect(@node.block.parent).not_to be_nil
        expect(@node.block.parent.height).to equal(560178)
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(560177)
      end
    end

    describe "Bitcoin Core 0.10.3" do
      before do
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
        expect(@node.block.height).to equal(560179)
        expect(@node.block.parent).not_to be_nil
        expect(@node.block.parent.height).to equal(560178)
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(560177)
        expect(@node.block.parent.parent.timestamp).to equal(1548500251)
      end
    end

    describe "Bitcoin ABC" do
      before do
        @node = build(:node, coin: "BCH")
        @node.client.mock_coin("BCH")
        @node.poll!
      end

      it "should have correct data" do
        expect(@node.version).to equal(180500)
        expect(@node.block.timestamp).to equal(1548498742)
      end
    end
  end

  describe "check_if_behind!" do
    before do
      @A = build(:node)
      @A.poll!

      @B = build(:node)
      @B.poll!
    end

    it "should detect if node A and B are at the same block" do
      expect(@A.check_if_behind!(@B)).to eq(nil)
    end

    describe "when behind" do
      let(:user) { create(:user) }

      before do
        @B.client.mock_set_height(560177)
        @B.poll!
        @first_check = @A.check_if_behind!(@B)
        Timecop.freeze(Time.now + 15 * 60)
      end

      it "should be false if the difference is recent" do
        expect(@first_check).to eq(false)
      end

      it "should detect if node A is behind node B" do
        lag = @A.check_if_behind!(@B)
        expect(lag).not_to be_nil
        expect(lag.node_a).to eq(@A)
        expect(lag.node_b).to eq(@B)
      end

      it "should be nil if the node is unreachable" do
        @A.client.mock_unreachable
        @A.poll!
        expect(@A.check_if_behind!(@B)).to eq(nil)
      end

      it "should be nil if the node is in initial block download" do
        @A.client.mock_ibd(true)
        @A.poll!
        expect(@A.ibd).to eq(true)
        expect(@A.check_if_behind!(@B)).to eq(nil)
      end

      it "should be nil if the node has no peers" do
        @A.client.mock_peer_count(0)
        @A.poll!
        expect(@A.peer_count).to eq(0)
        expect(@A.check_if_behind!(@B)).to eq(nil)
      end

      it "should send an email to all users" do
        expect(User).to receive(:all).and_return [user]
        expect { @A.check_if_behind!(@B) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "should send email only once" do
        expect(User).to receive(:all).and_return [user]
        expect { @A.check_if_behind!(@B) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect { @A.check_if_behind!(@B) }.to change { ActionMailer::Base.deliveries.count }.by(0)
      end

    end
  end

  describe "class" do
    describe "poll!" do
      it "should call poll! on all nodes, followed by check_laggards!" do
        node = create(:node_with_block)
        expect(Node).to receive(:all).and_return [node]
        expect(Node).to receive(:check_laggards!)
        expect(node).to receive(:poll!)
        Node.poll!
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
        expect(Node).to receive(:bitcoin_by_version).and_wrap_original {|relation|
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
  end
end
