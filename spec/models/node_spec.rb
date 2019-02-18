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
        @node.reload
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
        @node.reload
        expect(@node.block.height).to equal(560178)
        expect(@node.block.parent.parent).to be_nil
      end

      it "should not store intermediate blocks during initial blockchain download" do
        @node.client.mock_ibd(true)
        @node.client.mock_set_height(976)
        @node.poll!
        @node.reload
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
        @node.reload
        expect(@node.block.height).to equal(560177)
        expect(@node.block.parent).to be_nil

        # Two blocks later, now it should fetch intermediate blocks:
        @node.client.mock_set_height(560179)
        @node.poll!
        @node.reload
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

  describe "check_chaintips!" do
    before do
      @A = build(:node)
      @A.client.mock_version(170100)
      @A.client.mock_set_height(560176)
      @A.poll!
      @A.client.mock_set_height(560178)
      @A.poll!

      @B = build(:node)
      @B.client.mock_version(160300)
      @B.client.mock_set_height(560176)
      @B.poll!
      @B.client.mock_set_height(560178)
      @B.poll!
    end

    describe "only an active chaintip" do
      before do
        @B.client.mock_chaintips([
          {
            "height" => 560178,
            "hash" => "00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9",
            "branchlen" => 0,
            "status" => "active"
          }
        ])
      end
      it "should do nothing" do
        expect(@B.check_chaintips!).to eq(nil)
      end
    end

    describe "one active and one valid-fork chaintip" do
      before do
        @B.client.mock_chaintips([
          {
            "height" => 560178,
            "hash" => "00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9",
            "branchlen" => 0,
            "status" => "active"
          }, {
            "height" => 560178,
            "hash" => "0000000000000000000000000000000000000000000000000000000000560178",
            "branchlen" => 2,
            "status" => "valid-fork"
          }
        ])
        # Add intermediate fork blofk 560177, same work, created slight later
        @B.client.mock_add_block(560177, 1548500252, "000000000000000000000000000000000000000004dac9d20e304bee0e69b31a", "0000000000000000000000000000000000000000000000000000000000560177")

        # Add valid-fork block 560178, same work, created slight later
        @B.client.mock_add_block(560178, 1548500251, "000000000000000000000000000000000000000004dacf2c0c949abdc5c2c38f", "0000000000000000000000000000000000000000000000000000000000560178", "0000000000000000000000000000000000000000000000000000000000560177")

        @B.poll!
      end

      it "should return nothing" do
        expect(@B.check_chaintips!).to eq(nil)
      end

      it "should add the valid fork blocks up to the common ancenstor" do
        expect(@B.block.parent).not_to be_nil

        @B.check_chaintips!

        fork_block = Block.find_by(block_hash: "0000000000000000000000000000000000000000000000000000000000560178")
        expect(fork_block).not_to be_nil
        expect(fork_block.parent).not_to be_nil
        expect(fork_block.parent.height).to eq(560177)
        expect(fork_block.parent.block_hash).to eq("0000000000000000000000000000000000000000000000000000000000560177")
        expect(fork_block.parent.parent).not_to be_nil
        expect(fork_block.parent.parent.height).to eq(560176)
      end

      it "should ignore forks more than 1000 blocks ago" do
        @B.client.mock_chaintips([
          {
            "height" => 560178,
            "hash" => "00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9",
            "branchlen" => 0,
            "status" => "active"
          }, {
            "height" => 400000,
            "hash" => "00000000000000000000000000000000000000000000000000000000004000000",
            "branchlen" => 1,
            "status" => "valid-fork"
          }
        ])
        @B.check_chaintips!
        fork_block = Block.find_by(block_hash: "0000000000000000000000000000000000000000000000000000000000560178")
        expect(fork_block).to be_nil
      end
    end

    describe "one active and one invalid chaintip, not in our db" do
      before do
        @B.client.mock_chaintips([
          {
            "height" => 560178,
            "hash" => "00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9",
            "branchlen" => 0,
            "status" => "active"
          }, {
            "height" => 560179,
            "hash" => "000000000000000000017b592e9ecd6ce8ab9b5a2f391e21ee2e80b022a7dafc",
            "branchlen" => 0,
            "status" => "invalid"
          }
        ])
      end
      it "should do nothing" do
        expect(@B.check_chaintips!).to eq(nil)
      end
    end

    describe "one active and one invalid chaintip in our db" do
      let(:user) { create(:user) }

      before do
        # Make node A accept the block:
        @A.client.mock_set_height(560179)
        @A.poll!
        @B.client.mock_chaintips([
          {
            "height" => 560178,
            "hash" => "00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9",
            "branchlen" => 0,
            "status" => "active"
          },
          {
            "height" => 560179,
            "hash" => "000000000000000000017b592e9ecd6ce8ab9b5a2f391e21ee2e80b022a7dafc",
            "branchlen" => 0,
            "status" => "invalid"
          }
        ])
      end
      it "should return failing block" do
        disputed_block = @A.block
        expect(disputed_block.height).to eq(560179)
        expect(disputed_block.block_hash).to eq("000000000000000000017b592e9ecd6ce8ab9b5a2f391e21ee2e80b022a7dafc")
        expect(@B.check_chaintips!).to eq(disputed_block)
      end

      it "should be nil if the node is unreachable" do
        @B.client.mock_unreachable
        @B.poll!
        expect(@B.check_chaintips!).to eq(nil)
      end

      it "should store an InvalidBlock entry" do
        disputed_block = @B.check_chaintips!
        expect(InvalidBlock.count).to eq(1)
        expect(InvalidBlock.first.block).to eq(disputed_block)
        expect(InvalidBlock.first.node).to eq(@B)
      end

      it "should send an email to all users" do
        expect(User).to receive(:all).and_return [user]
        expect { @B.check_chaintips! }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "should send email only once" do
        expect(User).to receive(:all).and_return [user]
        expect { @B.check_chaintips! }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect { @B.check_chaintips! }.to change { ActionMailer::Base.deliveries.count }.by(0)
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
      it "should call poll! on all nodes, followed by check_laggards! and check_chaintips!" do
        node1 = create(:node_with_block, coin: "BTC", version: 170000)
        node2 = create(:node_with_block, coin: "BTC", version: 160000)
        node3 = create(:node_with_block, coin: "BCH")

        expect(Node).to receive(:check_laggards!)

        expect(Node).to receive(:check_chaintips!)

        expect(Node).to receive(:bitcoin_by_version).and_wrap_original {|relation|
          relation.call.each {|node|
                expect(node).to receive(:poll!)
          }
        }

        expect(Node).to receive(:altcoin_by_version).once().and_wrap_original {|relation|
          relation.call.each {|node|
            expect(node).to receive(:poll!)
          }
        }

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

    describe "check_chaintips!" do
      before do
        @A = build(:node)
        @A.client.mock_version(170100)
        @A.poll!

        @B = build(:node)
        @B.client.mock_version(100300)
        @B.poll!
      end

      it "should call check_chaintips! against nodes" do
        expect(Node).to receive(:bitcoin_by_version).and_wrap_original {|relation|
          relation.call.each {|record|
              expect(record).to receive(:check_chaintips!)
          }
        }
        Node.check_chaintips!
      end
    end
  end
end
