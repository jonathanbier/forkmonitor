require "rails_helper"
require "bitcoind_helper"

RSpec.describe StaleCandidate, :type => :model do
  let(:test) { TestWrapper.new() }

  before do
    stub_const("BitcoinClient::Error", BitcoinClientMock::Error)
    stub_const("BitcoinClient::ConnectionError", BitcoinClientPython::ConnectionError)
    stub_const("BitcoinClient::PartialFileError", BitcoinClientPython::PartialFileError)
    stub_const("BitcoinClient::BlockPrunedError", BitcoinClientPython::BlockPrunedError)

    allow(Node).to receive("set_pool_for_block!").and_return(nil)
    test.setup(num_nodes: 2, extra_args: [['-whitelist=noban@127.0.0.1']] * 2)
    @nodeA = create(:node_python)
    @nodeA.client.set_python_node(test.nodes[0])
    @nodeA.client.generate(104) # Mature coins

    @nodeB = create(:node_python)
    @nodeB.client.set_python_node(test.nodes[1])

    test.sync_blocks()

    address_a = @nodeA.client.getnewaddress()
    address_b = @nodeB.client.getnewaddress()

    # Transasction shared between nodes
    tx1_id = @nodeA.client.sendtoaddress(address_a, 1)
    test.sync_mempools()

    test.disconnect_nodes(@nodeA.client, 1)
    assert_equal(0, @nodeA.client.getpeerinfo().count)

    # Transaction to be mined in block 105 by node A, and later by node B
    @tx2_id = @nodeA.client.sendtoaddress(address_b, 1)
    @tx2_raw = @nodeA.getrawtransaction(@tx2_id)

    # Transaction to be bumped and mined in block 105 by node A. Node B will use the unbumped version.
    @tx3_id = @nodeA.client.sendtoaddress(address_b, 1, "", "", false, true)
    @tx3_raw = @nodeA.getrawtransaction(@tx3_id)
    @tx3_bumped_id = @nodeA.client.bumpfee(@tx3_id)["txid"]
    @nodeB.client.sendrawtransaction(@tx3_raw)

    # Transaction to be doublespent
    @tx4_id = @nodeA.client.sendtoaddress(address_a, 1, "", "", false, true) # marked RBF, but that's irrelevant
    tx4 = @nodeA.client.getrawtransaction(@tx4_id ,1)
    # TODO: use 'send' RPC (with addtowallet=false) after rebasing vendor/bitcoin
    psbt = @nodeA.client.walletcreatefundedpsbt(
      [{"txid": tx4["vin"][0]["txid"], "vout": tx4["vin"][0]["vout"]}],
      [{address_b => 1}],
    )["psbt"]
    psbt = @nodeA.client.walletprocesspsbt(psbt, true)
    assert(psbt["complete"])
    psbt = @nodeA.client.finalizepsbt(psbt["psbt"])
    @tx4_replaced_id = @nodeB.client.sendrawtransaction(psbt["hex"])

    # puts "tx1: #{ tx1_id }"
    # puts "tx2: #{ @tx2_id }"
    # puts "tx3: #{ @tx3_id } -> #{ @tx3_bumped_id }"
    # puts "tx4: #{ @tx4_id } -> #{ @tx4_replaced_id }"

    @nodeA.client.generate(2)
    @nodeB.client.generate(2) # alternative chain with same length
    @nodeA.poll!
    @nodeB.poll!
    @nodeA.reload
    expect(@nodeA.block.height).to eq(@nodeB.block.height)
    expect(@nodeA.block.block_hash).not_to eq(@nodeB.block.block_hash)
    test.connect_nodes(@nodeA.client, 1)
    # Don't sync, because there's no winning chain, so test framework times out
    # test.sync_blocks()

    allow(Block).to receive(:find_by).and_wrap_original { |m, *args|
      block = m.call(*args)
      if !block.nil?
        allow(block).to receive(:first_seen_by).and_return block.first_seen_by_id == @nodeA.id ? @nodeA : @nodeB
      end
      block
    }
  end

  after do
    test.shutdown()
  end

  describe "find_or_generate" do
    it "should create StaleCandidate" do
      s = StaleCandidate.find_or_generate(:btc, 105)
      expect(s).to_not be_nil
      s.prime_cache
      expect(s.n_children).to eq(2)
    end

    it "should add transactions" do
      s = StaleCandidate.find_or_generate(:btc, 105)
      # Node A block 105 should contain tx1, tx2, tx3 (bumped) and  tx4 (bumped)
      block = Block.find_by!(height: 105, first_seen_by: @nodeA)
      expect(block.transactions.where(is_coinbase: false).count).to eq(4)

      # Node B block 105 should only contain tx1, tx3 and tx4
      block = Block.find_by!(height: 105, first_seen_by: @nodeB)
      expect(block.transactions.where(is_coinbase: false).count).to eq(3)
    end

  end

  describe "confirmed_in_one_branch" do
    before do
      @s = StaleCandidate.find_or_generate(:btc, 105)
      expect(@s).to_not be_nil
      @s.prime_cache
    end

    it "should contain tx2, tx3&4 and bumped tx3&4" do
      expect(@s.confirmed_in_one_branch.count).to eq(5)
      expect(@s.confirmed_in_one_branch).to include(@tx2_id)
      expect(@s.confirmed_in_one_branch).to include(@tx3_id)
      expect(@s.confirmed_in_one_branch).to include(@tx3_bumped_id)
      expect(@s.confirmed_in_one_branch).to include(@tx4_id)
      expect(@s.confirmed_in_one_branch).to include(@tx4_replaced_id)
    end

    describe "when one chain is longer" do
      before do
        test.disconnect_nodes(@nodeA.client, 1)
        assert_equal(0, @nodeA.client.getpeerinfo().count)
        # this mines tx2
        @nodeA.client.generate(1)
        @nodeA.poll!
        @s.expire_cache
        @s.prime_cache
      end

      it "should contain original tx3 and replaced tx4" do
        expect(@s.confirmed_in_one_branch.count).to eq(2)
        expect(@s.confirmed_in_one_branch).to include(@tx3_id)
        expect(@s.confirmed_in_one_branch).to include(@tx4_replaced_id)
      end
    end
  end

  describe "double_spent_in_one_branch" do
    before do
      @s = StaleCandidate.find_or_generate(:btc, 105)
      expect(@s).to_not be_nil
      @s.prime_cache
    end

    it "should contain tx3 and tx4" do
      expect(@s.double_spent_in_one_branch.count).to eq(2)
      expect(@s.double_spent_in_one_branch).to include(@tx3_bumped_id)
      expect(@s.double_spent_in_one_branch).to include(@tx4_id)
    end
  end

  describe "rbf" do
    before do
      @s = StaleCandidate.find_or_generate(:btc, 105)
      expect(@s).to_not be_nil
      @s.prime_cache
    end

    it "should contain tx3 bumped" do
      # It picks an arbitrary "shortest" chain when both are the same length
      expect(@s.rbf.count).to eq(1)
      expect(@s.rbf).to include(@tx3_bumped_id)
    end

    describe "when one chain is longer" do
      before do
        test.disconnect_nodes(@nodeA.client, 1)
        assert_equal(0, @nodeA.client.getpeerinfo().count)
        # this mines tx2
        @nodeA.client.generate(1)
        @nodeA.poll!
        @s.expire_cache
        @s.prime_cache
      end

      it "should contain tx3" do
        expect(@s.rbf.count).to eq(1)
        expect(@s.rbf).to include(@tx3_id)
      end
    end
  end

  describe "self.check!" do
    let(:user) { create(:user) }

    before do
      allow(User).to receive(:all).and_return [user]
    end

    it "should trigger potential stale block alert" do
      expect(User).to receive(:all).and_return [user]

      # One alert for the lowest height:
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      # Just once...
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "should be quiet at an invalid block alert" do
      i = InvalidBlock.create(block: @nodeA.block, node: @nodeA)
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "should be quiet after an invalid block alert" do
      i = InvalidBlock.create(block: @nodeA.block.parent, node: @nodeA)
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "should notify again if alert was dismissed" do
      InvalidBlock.create(block: @nodeA.block.parent, node: @nodeA, dismissed_at: Time.now)
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "should work for headers_only block" do
      @nodeB.block.update headers_only: true, pool: nil, tx_count: nil, timestamp: nil, work: nil, parent_id: nil, mediantime: nil, first_seen_by_id: nil
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "should not also create one if the race continues 1 more block" do
      test.disconnect_nodes(@nodeA.client, 1)
      assert_equal(0, @nodeA.client.getpeerinfo().count)
      @nodeA.client.generate(1)
      @nodeB.client.generate(1)
      @nodeA.poll!
      @nodeB.poll!
      @nodeA.reload
      expect(@nodeA.block.height).to eq(@nodeB.block.height)
      expect(@nodeA.block.block_hash).not_to eq(@nodeB.block.block_hash)
      test.connect_nodes(@nodeA.client, 1)

      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  describe "self.process!" do
    before do
      StaleCandidate.check!(:btc) # Create stale candidate entry at height 105
      expect(StaleCandidate.count).to eq(1)
      expect(StaleCandidate.first.height).to eq(105)
      StaleCandidate.process!(:btc) # Fetch transactions from descendant blocks

    end

    it "should add transactions for descendant blocks" do
      # Make node B chain win:
      @nodeB.client.generate(1) # 105
      test.sync_blocks()

      # Transaction 2 should be in mempool A now, but it won't broadcast
      @nodeA.client.sendrawtransaction(@tx2_raw)
      test.sync_mempools()
      # Transaction 2 should be in the new block
      @nodeA.client.generate(1) # 108
      test.sync_blocks()

      @nodeA.poll!
      @nodeB.poll!

      StaleCandidate.process!(:btc) # Fetch transactions from descendant blocks
      # Node B block 108 should contain tx2
      block = Block.find_by!(height: 108)
      expect(block.transactions.where(is_coinbase: false).count).to eq(1)
    end

    it "should stop adding transactions after N descendant blocks" do
      # Make node B chain win:
      @nodeB.client.generate(11)
      test.sync_blocks()

      # Transaction 2 should be in mempool A now, but it won't broadcast
      @nodeA.client.sendrawtransaction(@tx2_raw)
      test.sync_mempools()
      # Transaction 2 should be in the new block
      @nodeA.client.generate(1) # 116
      test.sync_blocks()

      @nodeA.poll!
      @nodeB.poll!

      StaleCandidate.process!(:btc) # Fetch transactions from descendant blocks
      # Node B block 118 should contain tx2
      block = Block.find_by!(height: 118)
      expect(block.transactions.where(is_coinbase: false).count).to eq(0)
    end
  end


end
