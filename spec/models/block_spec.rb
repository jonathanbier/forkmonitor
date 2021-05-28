require "rails_helper"
require "bitcoind_helper"

RSpec.describe Block, :type => :model do
  let(:test) { TestWrapper.new() }

  def setup_python_nodes
    # Node A with mirror node, node B
    # Create two blocks and sync
    @use_python_nodes = true

    stub_const("BitcoinClient::Error", BitcoinClientPython::Error)
    stub_const("BitcoinClient::ConnectionError", BitcoinClientPython::ConnectionError)
    stub_const("BitcoinClient::NodeInitializingError", BitcoinClientPython::NodeInitializingError)
    stub_const("BitcoinClient::TimeOutError", BitcoinClientPython::TimeOutError)
    stub_const("BitcoinClient::BlockNotFoundError", BitcoinClientPython::BlockNotFoundError)
    test.setup(num_nodes: 3, extra_args: [['-whitelist=noban@127.0.0.1']] * 3)
    @nodeA = create(:node_python_with_mirror)
    @nodeA.client.set_python_node(test.nodes[0])
    @nodeA.mirror_client.set_python_node(test.nodes[1])

    @nodeB = create(:node_python)
    @nodeB.client.set_python_node(test.nodes[2])
    @nodeA.client.generate(2)
    test.sync_blocks()

    @nodeA.poll!
    @nodeA.poll_mirror!
    @nodeA.reload
    assert_equal(@nodeA.block.height, 2)
    assert_equal(@nodeA.mirror_block.height, 2)

    @nodeB.poll!
    @nodeB.reload
    assert_equal(@nodeB.block.height, 2)

    assert_equal(Chaintip.count, 0)

    allow(Node).to receive(:with_mirror).with(:btc).and_return [@nodeA]
    allow(Node).to receive(:bitcoin_core_by_version).and_return [@nodeA, @nodeB]
  end

  after do
    if @use_python_nodes
      test.shutdown()
    end
  end

  before do
    stub_const("BitcoinClient::Error", BitcoinClientMock::Error)
    stub_const("BitcoinClient::ConnectionError", BitcoinClientMock::ConnectionError)
    stub_const("BitcoinClient::PartialFileError", BitcoinClientMock::PartialFileError)
    stub_const("BitcoinClient::BlockPrunedError", BitcoinClientMock::BlockPrunedError)
    stub_const("BitcoinClient::BlockNotFoundError", BitcoinClientMock::BlockNotFoundError)
    stub_const("BitcoinClient::MethodNotFoundError", BitcoinClientMock::MethodNotFoundError)
    stub_const("BitcoinClient::TimeOutError", BitcoinClientMock::TimeOutError)
  end

  describe "log2_pow" do
    it "should be log2(pow)" do
      block = create(:block, work: "00000000000000000000000000000001")
      expect(block.log2_pow).to eq(0.0)
      block = create(:block, work: "00000000000000000000000000000002")
      expect(block.log2_pow).to eq(1.0)
    end
  end

  describe "summary" do
    it "should show the pool" do
      block = create(:block, pool: "Antpool")
      expect(block.summary).to include("Antpool")
    end
    it "should show 'unknown pool'" do
      block = create(:block, pool: nil)
      expect(block.summary).to include("unknown pool")
    end
    it "should include the block size in MB" do
      block = create(:block, pool: "Antpool", size: 300000)
      expect(block.summary).to include("0.3 MB")
    end
    it "should round the block size to two decimals" do
      block = create(:block, pool: "Antpool", size: 289999)
      expect(block.summary).to include("0.29 MB")
    end
    it "should show time of day if requested" do
      block = create(:block, pool: nil, size: nil, timestamp: 1566575008)
      expect(block.summary(time: true)).to include("(15:43:28")
    end
    it "should not show time of day if timestamp field is missing" do
      block = create(:block, pool: nil, size: nil, timestamp: nil)
      expect(block.summary(time: true)).not_to include("(15:43:28")
    end
    it "should use interpunction" do
      block = create(:block, block_hash: "0000000", pool: "Antpool", size: 289999, timestamp: 1566575008)
      expect(block.summary()).to eq("0000000 (0.29 MB, Antpool)")
      expect(block.summary(time: true)).to eq("0000000 (0.29 MB, 15:43:28 by Antpool)")
      block.pool = nil
      expect(block.summary(time: true)).to eq("0000000 (0.29 MB, 15:43:28 by unknown pool)")
      block.size = nil
      expect(block.summary).to eq("0000000 (unknown pool)")
    end
    it "should show first seen by if requested" do
      block = create(:block, pool: nil, first_seen_by: build(:node))
      expect(block.summary(first_seen_by: true)).to include("first seen by Bitcoin Core 0.17.1")
    end
    it "should not show first seen by if unknown" do
      block = create(:block, pool: nil, first_seen_by: nil)
      expect(block.summary(first_seen_by: true)).not_to include("first seen by Bitcoin Core 0.17.1")
    end

  end

  describe "version_bits" do
    it "should be empty by default" do
      block = create(:block)
      expect(block.version_bits).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    end

    it "should detect bit 1" do
      block = create(:block, version: 0x20000001)
      expect(block.version_bits).to eq([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    end
  end

  describe "maximum_inflation" do
    COIN = 100000000

    it "should be 12.5 for BTC in mid 2019" do
      @block = build(:block, height: 596808)
      expect(@block.max_inflation).to eq(12.5 * COIN)
    end

    it "should be 50 for BTC in 2009" do
      @block = build(:block, height: 100)
      expect(@block.max_inflation).to eq(50 * COIN)
    end

    it "should be 12.5 for BTC immediately before the 2020 halving" do
      @block = build(:block, height: 629999)
      expect(@block.max_inflation).to eq(12.5 * COIN)
    end

    it "should be 6.25 for BTC at the 2020 halving" do
      @block = build(:block, height: 630000)
      expect(@block.max_inflation).to eq(6.25 * COIN)
    end

    it "should be 0.00000009 for BTC at height 6090000" do
      @block = build(:block, height: 6090000)
      expect(@block.max_inflation).to eq(0.00000009 * COIN)
    end

    it "should be 0 for BTC as of height 6930000" do
      @block = build(:block, height: 6930000)
      expect(@block.max_inflation).to eq(0.00000000 * COIN)
    end

    it "should create slightly less than 21 million BTC" do
       @block = build(:block, height: 0)
       i=0
       coins = 0.0
       while i < 10000000 do
         @block.height = i
         coins += 1000 * @block.max_inflation
         i += 1000
       end
       expect(coins).to eq(20999999.9769 * COIN)
    end
  end

  describe "descendants" do
    before do
      # A -> B1 -> C1 -> D1
      #   -> B2
      @a = create(:block)
      @b1 = create(:block, parent: @a)
      @b2 = create(:block, parent: @a)
      @c1 = create(:block, parent: @b1)
      @d1 = create(:block, parent: @c1)
    end

    it "should not return itself" do
      expect(@a.descendants).not_to include(@a)
    end

    it "should return all blocks descending" do
      expect(@b1.descendants).to include(@c1)
      expect(@b1.descendants).to include(@d1)
    end

    it "should not return blocks that don't descend from it" do
      expect(@b2.descendants).not_to include(@c1)
    end
  end

  describe "branch_start" do
    before do
      # A -> B1 -> C1 -> D1
      #   -> B2 -> C2
      @a = create(:block)
      @b1 = create(:block, parent: @a)
      @b2 = create(:block, parent: @a)
      @c1 = create(:block, parent: @b1)
      @c2 = create(:block, parent: @b2)
      @d1 = create(:block, parent: @c1)
    end

    it "should fail if comparing to self" do
      expect { @a.branch_start(@a) }.to raise_error("same block")
    end

    it "should fail if comparing on same branch" do
      expect { @b1.branch_start(@c1) }.to raise_error("same branch")
      expect { @c1.branch_start(@d1) }.to raise_error("same branch")
    end

    it "should find the branch start" do
      expect( @d1.branch_start(@c2)).to eq(@b1)
      expect( @c2.branch_start(@d1)).to eq(@b2)
    end
  end

  describe "fetch_transactions!" do
    before do
      @node = create(:node)
    end

    it "should fetch transactions for the block" do
      expect(Block).to receive(:find_by).and_call_original # Sanity check for later test
      @block = create(:block, block_hash: "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377", first_seen_by: @node)
      @block.fetch_transactions! # Mock client knows one transaction for this block
      expect(@block.transactions.count).to eq(1)
    end

    it "should not fetch twice" do
      expect(Block).to receive(:find_by).once.and_call_original
      @block = create(:block, block_hash: "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377", first_seen_by: @node)
      @block.fetch_transactions!
      @block.fetch_transactions!
      expect(@block.transactions.count).to eq(1)
    end

    it "should mark block as pruned if it can't be fetched due to pruning" do
      @block = create(:block, block_hash: "0000000000000000000000000000000000000000000000000000000000000001", first_seen_by: @node)
      @block.fetch_transactions!
      expect(@block.pruned).to eq(true)
    end

    it "should try the modern node if a block was pruned" do
      @block = create(:block, block_hash: "0000000000000000000000000000000000000000000000000000000000000001", first_seen_by: @node)
      @block.fetch_transactions!
      expect(Block).to receive(:find_by).and_call_original
      expect{ @block.fetch_transactions! }.to raise_error Node::NoMatchingNodeError
    end
  end

  describe "create_or_update_with" do
    before do
      @node = build(:node)
      @block_info = {
        "hash" => "000000000000000000063d6a38161b2a69ba6bfe84f31272ffc3c36308b55574",
        "confirmations" => 1,
        "strippedsize" => 889912,
        "size" => 1328797,
        "weight" => 3998533,
        "height" => 584492,
        "version" => 536870912,
        "versionHex" => "20000000",
        "merkleroot" => "32a561821430a709585266f9642a6dd808de59eea5b198497f577127b4a4e3e8",
        "tx" => [
        ],
        "time" => 1562591342,
        "mediantime" => 1562589082,
        "nonce" => 663397958,
        "bits" => "1723792c",
        "difficulty" => 7934713219630.606,
        "chainwork" => "00000000000000000000000000000000000000000714a4cd58e70c3c61429c91",
        "nTx" => 3024,
        "previousblockhash" => "00000000000000000005b127b27cc0771e1b0fcb18dcba4c0644f2bb4dc90597"
      }
      allow(Node).to receive("set_pool_tx_ids_fee_total_for_block!").and_return(nil)
    end

    it "should store the version" do
      @block = Block.create_or_update_with(@block_info, false, @node, true)
      expect(@block.version).to eq(536870912)
    end

    it "should store number of transactions" do
      @block = Block.create_or_update_with(@block_info, false, @node, true)
      expect(@block.tx_count).to eq(3024)
    end

    it "should store size" do
      @block = Block.create_or_update_with(@block_info, false, @node, true)
      expect(@block.size).to eq(1328797)
    end

  end

  describe "make_active_on_mirror!" do
    before do
      setup_python_nodes()

      test.disconnect_nodes(0, 1) # disconnect A from mirror (A')
      test.disconnect_nodes(0, 2) # disconnect A from B
      test.disconnect_nodes(1, 2) # disconnect A' from B
      assert_equal(0, @nodeA.client.getpeerinfo().count)
      assert_equal(0, @nodeA.mirror_client.getpeerinfo().count)

      @nodeA.client.generate(1) # this active, but changes to valid-fork after reconnect
      @nodeB.client.generate(2) # active one node B
      @nodeA.poll!
      @nodeB.poll!
      test.connect_nodes(0, 1)
      test.connect_nodes(0, 2)
      test.connect_nodes(1, 2)

      test.sync_blocks()

      chaintipsA = @nodeA.client.getchaintips()

      expect(chaintipsA.length).to eq(2)
      expect(chaintipsA[-1]["status"]).to eq("valid-fork")

      Chaintip.check!(:btc, [@nodeA])
      @valid_fork_block = Block.find_by(block_hash: chaintipsA[-1]["hash"])
    end

    it "should change the mirror's active chaintip" do
      @valid_fork_block.make_active_on_mirror!(@nodeA)
      chaintipsA = @nodeA.mirror_client.getchaintips()
      expect(chaintipsA[1]["status"]).to eq("active")
      expect(chaintipsA[1]["hash"]).to eq(@valid_fork_block.block_hash)
    end
  end

  describe "validate_fork!" do
    before do
      setup_python_nodes()

      test.disconnect_nodes(0, 1) # disconnect A from mirror (A')
      test.disconnect_nodes(0, 2) # disconnect A from B
      test.disconnect_nodes(1, 2) # disconnect A' from B
      assert_equal(0, @nodeA.client.getpeerinfo().count)
      assert_equal(0, @nodeA.mirror_client.getpeerinfo().count)

      @nodeA.client.generate(2) # this is and remains active
      @nodeB.client.generate(1) # Node A will see this as valid-headers after reconnect
      @nodeA.poll!
      @nodeB.poll!
      test.connect_nodes(0, 1)
      test.connect_nodes(0, 2)
      test.connect_nodes(1, 2)

      test.sync_blocks()

      chaintipsA = @nodeA.client.getchaintips()

      expect(chaintipsA.length).to eq(2)
      expect(chaintipsA[-1]["status"]).to eq("headers-only")
      @block = Block.find_by(block_hash: chaintipsA[-1]["hash"])
    end

    it "should skip if the node already marked it as (in)valid" do
      @block.update marked_valid_by: [@nodeA.id]
      expect(@block).not_to receive(:make_active_on_mirror!)
      @block.validate_fork!(@nodeA)
    end

    it "should skip if the node doesn't have a mirror" do
      @nodeA.update mirror_rpchost: nil
      expect(@block).not_to receive(:make_active_on_mirror!)
      @block.validate_fork!(@nodeA)
    end

    it "should skip if the mirror node doesn't have the block" do
      expect { @nodeA.mirror_client.getblock(@block.block_hash, 1) }.to raise_error(BitcoinClient::BlockNotFoundError)
    end

    describe "when mirror client has block" do
      before do
        assert_equal(@nodeA.mirror_client.submitblock(@nodeB.client.getblock(@block.block_hash, 0)), "inconclusive")
      end

      it "should roll the mirror back" do
        expect(@block).to receive(:make_active_on_mirror!).with(@nodeA).and_call_original
        @block.validate_fork!(@nodeA)
      end

      it "should mark the block as considered valid" do
        @block.validate_fork!(@nodeA)
        expect(@block.marked_valid_by).to include(@nodeA.id)
      end

      it "should roll the mirror forward" do
        expect(@nodeA.mirror_client).to receive(:reconsiderblock)
        @block.validate_fork!(@nodeA)
      end

    end
  end

  describe "self.pool_from_coinbase_tx" do
    before do
      create(:antpool)
      create(:f2pool)
    end

    it "should find Antpool" do
      # response from getrawtransaction 99d1ead20f83d090f2878559446abaa5db320524f63011ed1b71bfef47c5ac02 true
      tx = {
        "txid" => "99d1ead20f83d090f2878559446abaa5db320524f63011ed1b71bfef47c5ac02",
        "hash" => "b1bf7d584467258e368199d9851e820176bf06f2208f1e2ec6433f21eac5842d",
        "version" => 1,
        "size"=>252,
        "vsize"=>225,
        "weight"=>900,
        "locktime"=>0,
        "vin"=>[
          {
            "coinbase"=>"0375e8081b4d696e656420627920416e74506f6f6c34381d00330020c85d207ffabe6d6d2bcb43e33b12c011f5e99afe1b4478d1001b7ce90db6b7c937793e89fafae6dd040000000000000052000000eb0b0200",
            "sequence"=>4294967295
          }
        ],
        "vout"=>[
          {
            "value"=>13.31801952,
            "n"=>0,
            "scriptPubKey"=>{"asm"=>"OP_DUP OP_HASH160 edf10a7fac6b32e24daa5305c723f3de58db1bc8 OP_EQUALVERIFY OP_CHECKSIG", "hex"=>"76a914edf10a7fac6b32e24daa5305c723f3de58db1bc888ac", "reqSigs"=>1, "type"=>"pubkeyhash", "addresses"=>["1Nh7uHdvY6fNwtQtM1G5EZAFPLC33B59rB"]}
          }, {
            "value"=>0.0,
            "n"=>1,
            "scriptPubKey"=>{"asm"=>"OP_RETURN aa21a9ed53112dcef82ee73de0243da1fe7278468349c7098fa3db778383005238d28e0a", "hex"=>"6a24aa21a9ed53112dcef82ee73de0243da1fe7278468349c7098fa3db778383005238d28e0a", "type"=>"nulldata"}
          }
        ], "hex"=>"010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff540375e8081b4d696e656420627920416e74506f6f6c34381d00330020c85d207ffabe6d6d2bcb43e33b12c011f5e99afe1b4478d1001b7ce90db6b7c937793e89fafae6dd040000000000000052000000eb0b0200ffffffff0260af614f000000001976a914edf10a7fac6b32e24daa5305c723f3de58db1bc888ac0000000000000000266a24aa21a9ed53112dcef82ee73de0243da1fe7278468349c7098fa3db778383005238d28e0a0120000000000000000000000000000000000000000000000000000000000000000000000000",
        "blockhash"=>"0000000000000000001e93e79aa71bec43c72d671935e704b0713a4453e04183",
        "confirmations"=>14,
        "time"=>1562242070,
        "blocktime"=>1562242070
      }

      expect(Block.pool_from_coinbase_tx(tx)).to eq("Antpool")
    end

    it "should find F2Pool" do
      # Truncated response from getrawtransaction 87b72be71eab3fb8c452ea91ba0c21c4b9affa56386b0455ad50d3513c433484 true
      tx =  {
        "vin"=>[
          {
            "coinbase" => "039de8082cfabe6d6db6e2235d03234641c5859b7b1864addea7c0c2ef07a68bb8ebc178ac804f4b6910000000f09f909f000f4d696e656420627920776c3337373100000000000000000000000000000000000000000000000000000000050024c5aa2a",
            "sequence" => 0
          }
        ]
      }

      expect(Block.pool_from_coinbase_tx(tx)).to eq("F2Pool")
    end
  end

  describe "self.create_headers_only" do
    before do
      @node = build(:node)
    end

    it "should mark block as headers_only" do
      block = Block.create_headers_only(@node, 560182, "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377")
      expect(block.headers_only).to eq(true)
    end

    it "should set first seen by" do
      block = Block.create_headers_only(@node, 560182, "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377")
      expect(block.first_seen_by).to eq(@node)
    end

    it "should be updated by find_or_create_by" do
      allow(Node).to receive("set_pool_tx_ids_fee_total_for_block!").and_return(nil)
      block = Block.create_headers_only(@node, 560182, "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377")
      Block.create_or_update_with({
        "hash" => "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377",
        "height" => 560182,
        "nTx" => 3
      }, false, @node, nil)
      block.reload
      expect(block.headers_only).to eq(false)
      expect(block.tx_count).to eq(3)
    end

    it "should have a valid summary" do
      block = Block.create_headers_only(@node, 560182, "0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377")
      expect(block.summary(time: true, first_seen_by: true)).to eq("0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377 (10:57:31 by unknown pool, first seen by Bitcoin Core 0.17.1)")
    end
  end

  describe "self.find_missing" do
    before do
      setup_python_nodes()

      test.disconnect_nodes(0, 1) # disconnect A from mirror (A')
      test.disconnect_nodes(0, 2) # disconnect A from B
      test.disconnect_nodes(1, 2) # disconnect A' from B
      assert_equal(0, @nodeA.client.getpeerinfo().count)
      assert_equal(0, @nodeA.mirror_client.getpeerinfo().count)

      @nodeA.client.generate(2) # this is and remains active
      @nodeB.client.generate(1) # Node A will see this as valid-headers after reconnect
      @nodeA.poll!
      test.connect_nodes(0, 1)
      test.connect_nodes(0, 2)
      test.connect_nodes(1, 2)

      test.sync_blocks()

      chaintipsA = @nodeA.client.getchaintips()

      expect(chaintipsA.length).to eq(2)
      expect(chaintipsA[-1]["status"]).to eq("headers-only")

      Chaintip.check!(:btc, [@nodeA])
      @headers_only_block = Block.find_by(block_hash: chaintipsA[-1]["hash"])
      expect(@headers_only_block.headers_only).to eq(true)
    end

    it "should obtain block from other node if available" do
      Block.find_missing(:btc, 1, 1)
      @headers_only_block.reload
      expect(@headers_only_block.headers_only).to eq(false)
      expect(@headers_only_block.first_seen_by).to eq(@nodeB)
    end

    it "should submit block to original node" do
      expect { @nodeA.client.getblock(@headers_only_block.block_hash, 1) }.to raise_error(BitcoinClient::BlockNotFoundError)
      Block.find_missing(:btc, 1, 1)
      res = @nodeA.client.getblock(@headers_only_block.block_hash, 1)
      expect(res["confirmations"]).to eq(-1)
    end

  end

end
