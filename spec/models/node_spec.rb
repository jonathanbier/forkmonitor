require "rails_helper"

RSpec.describe Node, :type => :model do
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

    # https://github.com/bitcoin-sv/bitcoin-sv/blob/v0.1.1/src/clientversion.h#L57-L64
    it "should handle SV version shift" do
      node = create(:node, version: 100010000, client_type: :sv, name: "Bitcoin SV")
      expect(node.name_with_version).to eq("Bitcoin SV 0.1.0")
    end

  end

  describe "poll!" do
    describe "on first run" do
      before do
        @node = build(:node)
        @node.client.mock_ibd(true)
      end

      it "should save the node" do
        @node.poll!
        expect(@node.id).not_to be_nil
      end

      it "should store the node version" do
        @node.poll!
        expect(@node.version).to eq(170100)
      end

      it "should parse v1.0.2 variant (e.g. Bcoin)" do
        @node.client.mock_version("v1.0.2")
        @node.client.mock_client_type(:bcoin)
        @node.poll!
        expect(@node.version).to eq(1000200)
      end

      it "should not store the latest block if in IBD" do
        @node.poll!
        expect(@node.block).to be_nil
      end

      it "should store the latest block if not in IBD" do
        @node.client.mock_ibd(false)
        @node.poll!
        expect(@node.block).not_to be_nil
        expect(@node.block.height).to equal(560176)
        expect(@node.block.first_seen_by).to eq(@node)
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

        @node.client.mock_set_height(560177)
        allow(@node).to receive("get_pool_for_block!").and_return("Antpool")
        @node.poll! # stores the block and node entry
      end

      it "should get IBD status" do
        @node.poll!
        expect(@node.ibd).to eq(false)
      end

      it "should update to the latest block" do
        @node.poll!
        expect(@node.block.height).to equal(560177)
      end

      it "should store pool for block" do
        expect(@node.block.pool).to eq("Antpool")
      end

      it "should store size and number of transactions in block" do
        @node.client.mock_set_height(560182)
        @node.poll!
        expect(@node.block.tx_count).to eq(1)
        expect(@node.block.size).to eq(250)
      end

      it "should store intermediate blocks" do
        @node.client.mock_set_height(560179)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560179)
        expect(@node.block.parent).not_to be_nil
        expect(@node.block.parent.height).to equal(560178)
        expect(@node.block.parent.first_seen_by).to eq(@node)
        expect(@node.block.parent.parent).not_to be_nil
        expect(@node.block.parent.parent.height).to equal(560177)
      end

      it "should not store blocks during initial blockchain download" do
        @node.client.mock_ibd(true)
        @node.client.mock_set_height(976)
        @node.poll!
        @node.reload
        expect(@node.block).to be_nil
      end

      it "should not fetch parent blocks older than 560176" do
        # Blocks during IBD are not stored
        @node.client.mock_ibd(true)
        @node.client.mock_set_height(976)
        @node.poll!
        expect(@node.block).to be_nil

        # Exit IBD, fetching all previous blocks would take forever, so don't:
        @node.client.mock_ibd(false)
        @node.client.mock_set_height(560176)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560176)
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

      it "should get IBD status by comparing to other nodes" do
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

    describe "libbitcoin" do
      before do
        @node = build(:node, client_type: :libbitcoin)
        @node.client.mock_client_type(:libbitcoin)
        @node.client.mock_version(nil)
        @node.poll!
      end

      it "should have correct data" do
        expect(@node.version).to equal(nil)
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

    describe "btcd" do
      before do
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
        @node = build(:node, coin: "BCH")
        @node.client.mock_coin("BCH")
        @node.client.mock_version(180500)
        @node.poll!
      end

      it "should have correct data" do
        expect(@node.version).to equal(180500)
        expect(@node.block.timestamp).to equal(1548498742)
      end

      it "should store intermediate blocks" do
        @node.client.mock_set_height(560178)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560178)
        expect(@node.block.parent.parent).not_to be_nil
      end

    end

    describe "Bitcoin SV" do
      before do
        @node = build(:node, coin: "BSV")
        @node.client.mock_coin("BSV")
        @node.client.mock_version(180500) # TODO: use a real SV version
        @node.poll!
      end

      it "should have correct data" do
        expect(@node.version).to equal(180500)
        expect(@node.block.timestamp).to equal(1548498742)
      end

      it "should store intermediate blocks" do
        @node.client.mock_set_height(560178)
        @node.poll!
        @node.reload
        expect(@node.block.height).to equal(560178)
        expect(@node.block.parent.parent).not_to be_nil
      end
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
      @node = build(:node, coin: "TBTC")
      @node.client.mock_coin("BCH")
      @node.client.mock_version(180500)
      @node.poll!
    end

    it "should have correct data" do
      expect(@node.version).to equal(180500)
      expect(@node.block.timestamp).to equal(1548498742)
    end

    it "should store intermediate blocks" do
      @node.client.mock_set_height(560178) # Mainnet based mock data
      @node.poll!
      @node.reload
      expect(@node.block.height).to equal(560178)
      expect(@node.block.parent.parent).not_to be_nil
    end

  end

  describe "check_chaintips!" do
    before do
      @A = create(:node)
      @A.client.mock_version(170100)
      @A.client.mock_set_height(560178)

      @B = create(:node)
      @B.client.mock_version(160300)
      @B.client.mock_set_height(560178)
    end

    describe "one node in IBD" do
      before do
        @A.client.mock_ibd(true)
        @A.poll!
      end
      it "should do nothing" do
        expect(@A.check_chaintips!).to eq(nil)
      end
      it "should not have chaintip entries" do
        expect(@A.chaintips.count).to eq(0)
      end
    end

    describe "only an active chaintip" do
      before do
        @A.client.mock_chaintips([
          {
            "height" => 560178,
            "hash" => "00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9",
            "branchlen" => 0,
            "status" => "active"
          }
        ])
        @A.poll!
      end
      it "should add a chaintip entry" do
        expect(@A.chaintips.count).to eq(0)
        @A.check_chaintips!
        expect(@A.chaintips.count).to eq(1)
        expect(@A.chaintips.first.block.height).to eq(560178)
      end
    end

    describe "one active and one valid-fork chaintip" do
      let(:user) { create(:user) }

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
        # Add intermediate fork block 560177, same work, created slight later
        @B.client.mock_add_block(560177, 1548500252, "000000000000000000000000000000000000000004dac9d20e304bee0e69b31a", "0000000000000000000000000000000000000000000000000000000000560177", "0000000000000000000b1e380c92ea32288b0106ef3ed820db3b374194b15aab")

        # Add valid-fork block 560178, same work, created slight later
        @B.client.mock_add_block(560178, 1548500251, "000000000000000000000000000000000000000004dacf2c0c949abdc5c2c38f", "0000000000000000000000000000000000000000000000000000000000560178", "0000000000000000000000000000000000000000000000000000000000560177")

        @B.poll!
      end

      it "should add a chaintip entry" do
        @B.check_chaintips!
        expect(@B.chaintips.count).to eq(2)
        expect(@B.chaintips.last.status).to eq("valid-fork")
      end

      it "should add the valid fork blocks up to the common ancenstor" do
        @B.check_chaintips!

        fork_block = Block.find_by(block_hash: "0000000000000000000000000000000000000000000000000000000000560178")
        expect(fork_block).not_to be_nil
        expect(fork_block.parent).not_to be_nil
        expect(fork_block.parent.height).to eq(560177)
        expect(fork_block.parent.block_hash).to eq("0000000000000000000000000000000000000000000000000000000000560177")
        expect(fork_block.parent.parent).not_to be_nil
        expect(fork_block.parent.parent.height).to eq(560176)
      end

      it "should trigger potential stale block alert" do
        expect(User).to receive(:all).twice.and_return [user]
        expect(Node).to receive(:bitcoin_core_by_version).twice.and_return [@A, @B]

        # One alert for each height:
        expect { Node.check_chaintips!(coins: ["BTC"]) }.to change { ActionMailer::Base.deliveries.count }.by(2)
        # Just once...
        expect { Node.check_chaintips!(coins: ["BTC"]) }.to change { ActionMailer::Base.deliveries.count }.by(0)
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
        @B.poll!
      end
      it "should add the active entry" do
        @B.check_chaintips!
        expect(@B.chaintips.count).to eq(1) # It won't add the invalid entry because it doesn't have the block
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
        @B.poll!
      end
      it "should store invalid tip" do
        disputed_block = @A.block
        expect(disputed_block.height).to eq(560179)
        expect(disputed_block.block_hash).to eq("000000000000000000017b592e9ecd6ce8ab9b5a2f391e21ee2e80b022a7dafc")
        @B.check_chaintips!
        expect(@B.chaintips.where(status: "invalid").count).to eq(1)
      end

      it "should be nil if the node is unreachable" do
        @B.client.mock_unreachable
        @B.poll!
        expect(@B.check_chaintips!).to eq(nil)
      end

      it "should store an InvalidBlock entry" do
        @B.check_chaintips!
        disputed_block = @B.chaintips.last.block
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
      # Prepare two nodes that are out of IBD and have been polled
      @A = build(:node)
      @A.client.mock_set_height(560176)
      @A.client.mock_ibd(true)
      @A.poll!
      @A.client.mock_ibd(false)
      @A.poll!

      @B = build(:node)
      @B.client.mock_set_height(560176)
      @B.client.mock_ibd(true)
      @B.poll!
      @B.client.mock_ibd(false)
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

      it "should be nil if other node is in initial block download" do
        @B.client.mock_ibd(true)
        @B.poll!
        expect(@B.ibd).to eq(true)
        expect(@A.check_if_behind!(@B)).to eq(nil)
      end

      it "should be nil if the node has no peers" do
        @A.client.mock_peer_count(0)
        @A.poll!
        expect(@A.peer_count).to eq(0)
        expect(@A.check_if_behind!(@B)).to eq(nil)
      end

      it "should allow 1 extra block for old nodes" do
        @A.client.mock_version(100300)
        @A.update version: 100300
        @A.poll!
        expect(@A.check_if_behind!(@B)).to eq(nil)

        @B.client.mock_set_height(560178)
        @B.poll!
        expect(@A.check_if_behind!(@B)).not_to eq(nil)
      end

      it "should detect if bcoin node A is behind (core) node B" do
        @A.client.mock_version("v1.0.2")
        @A.client.mock_client_type(:bcoin)
        @A.update version: "v1.0.2"
        @A.update client_type: :bcoin
        @A.poll!

        lag = @A.check_if_behind!(@B)
        expect(lag).not_to be_nil
        expect(lag.node_a).to eq(@A)
        expect(lag.node_b).to eq(@B)
      end

      it "should allow 1 extra block for btcd" do
        @A.client.mock_version(120000)
        @A.client.mock_client_type(:btcd)
        @A.update version: 120000
        @A.update client_type: :btcd
        @A.poll!
        expect(@A.check_if_behind!(@B)).to eq(nil)

        @B.client.mock_set_height(560178)
        @B.poll!
        expect(@A.check_if_behind!(@B)).not_to eq(nil)
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
      @node.block.find_ancestors!(@node)
      expect(Block.minimum(:height)).to equal(560176)
    end

    it "with block argument should fetch parents beyond the oldest block" do
      @node.client.mock_set_height(560182)
      @node.poll!
      @node.reload
      expect(@node.block.height).to equal(560182)
      expect(Block.count).to equal(7)

      @node.block.find_ancestors!(@node, 560176)
      expect(Block.count).to equal(7)
      expect(Block.minimum(:height)).to equal(560176)
    end
  end

  describe "get_pool_for_block!" do
    before do
      @block = create(:block, block_hash: "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377")
      @node = create(:node, coin: "BTC", block: @block)
    end

    it "should fetch the block" do
      expect(@node.client).to receive("getblock").and_call_original
      @node.get_pool_for_block!(@block.block_hash)
    end


    it "should not fetch the block if getblock is cached" do
      expect(@node.client).not_to receive("getblock")
      @node.get_pool_for_block!(@block.block_hash, {"tx" => ["0"]})
    end

    it "should call getrawtransaction on the coinbase" do
      expect(@node.client).to receive("getrawtransaction").and_call_original
      @node.get_pool_for_block!(@block.block_hash)
    end

    it "should pass getrawtransaction output to pool_from_coinbase_tx" do
      expect(Block).to receive(:pool_from_coinbase_tx)
      @node.get_pool_for_block!(@block.block_hash)
    end
  end

  describe "class" do
    describe "poll!" do
      it "should call poll! on all nodes, followed by check_laggards!, check_chaintips! and check_versionbits!" do
        node1 = create(:node_with_block, coin: "BTC", version: 170000)
        node2 = create(:node_with_block, coin: "BTC", version: 160000)
        node3 = create(:node_with_block, coin: "BCH")
        node4 = create(:node_with_block, coin: "BSV")

        expect(Node).to receive(:check_laggards!)

        expect(Node).to receive(:check_chaintips!)

        expect(Node).to receive(:bitcoin_core_by_version).and_wrap_original {|relation|
          relation.call.each {|node|
            expect(node).to receive(:poll!)
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

        expect(Node).to receive(:bsv_by_version).once().and_wrap_original {|relation|
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
      before do
        @node = build(:node_with_mirror)
        @node.mirror_client.invalidateblock("00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9")
      end
      
      it "should restore network and reconsider blocks" do
        expect(@node.mirror_client).to receive("setnetworkactive").with(true)
        expect(@node.mirror_client).to receive("reconsiderblock").with("00000000000000000016816bd3f4da655a4d1fd326a3313fa086c2e337e854f9")
        @node.restore_mirror
      end

    end

    describe "heavy_checks_repeat!" do
      before do
        @node = create(:node_with_mirror)
      end

      it "should call restore_mirror" do
        expect_any_instance_of(Node).to receive(:restore_mirror)
        Node.heavy_checks_repeat!({coins: ["BTC"]})
      end
      
      it "should call check_inflation!" do
        expect(InflatedBlock).to receive(:check_inflation!).with(:btc)

        Node.heavy_checks_repeat!({coins: ["BTC"]})
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

      it "should call check_chaintips! against nodes" do
        expect(Node).to receive(:bitcoin_core_by_version).and_wrap_original {|relation|
          relation.call.each {|record|
              expect(record).to receive(:check_chaintips!)
          }
        }
        Node.check_chaintips!(coins: ["BTC"])
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
  end
end
