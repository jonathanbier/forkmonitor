# frozen_string_literal: true

require 'rails_helper'
require 'bitcoind_helper'

RSpec.describe StaleCandidate do
  let(:test) { TestWrapper.new }

  before do
    allow(Node).to receive('set_pool_for_block!').and_return(nil)
    test.setup(num_nodes: 2, extra_args: [['-whitelist=noban@127.0.0.1']] * 2)
    @node_a = create(:node_python)
    @node_a.client.set_python_node(test.nodes[0])
    @node_a.client.createwallet
    @miner_addr = @node_a.client.getnewaddress
    @node_a.client.generatetoaddress(104, @miner_addr) # Mature coins

    @node_b = create(:node_python)
    @node_b.client.set_python_node(test.nodes[1])
    @node_b.client.createwallet

    test.sync_blocks

    address_a = @node_a.client.getnewaddress
    address_b = @node_b.client.getnewaddress

    # Transasction shared between nodes
    @tx_1_id = @node_a.client.sendtoaddress(address_a, 1)
    test.sync_mempools

    test.disconnect_nodes(0, 1)
    expect(@node_a.client.getpeerinfo.count).to eq(0)

    # Transaction to be mined in block 105 by node A, and later by node B
    @tx_2_id = @node_a.client.sendtoaddress(address_b, 1)
    @tx_2_raw = @node_a.getrawtransaction(@tx_2_id)

    # Transaction to be bumped and mined in block 105 by node A. Node B will use the unbumped version.
    @tx_3_id = @node_a.client.sendtoaddress(address_b, 1, '', '', false, true)
    @tx_3_raw = @node_a.getrawtransaction(@tx_3_id)
    @tx_3_bumped_id = @node_a.client.bumpfee(@tx_3_id)['txid']
    @node_b.client.sendrawtransaction(@tx_3_raw)

    # Transaction to be doublespent
    @tx_4_id = @node_a.client.sendtoaddress(address_a, 1, '', '', false, true) # marked RBF, but that's irrelevant
    tx_4 = @node_a.client.getrawtransaction(@tx_4_id, 1)
    # TODO: use 'send' RPC (with addtowallet=false) after rebasing vendor/bitcoin
    psbt = @node_a.client.walletcreatefundedpsbt(
      [{ txid: tx_4['vin'][0]['txid'], vout: tx_4['vin'][0]['vout'] }],
      [{ address_b => 1 }]
    )['psbt']
    psbt = @node_a.client.walletprocesspsbt(psbt, true)
    assert(psbt['complete'])
    psbt = @node_a.client.finalizepsbt(psbt['psbt'])
    @tx_4_replaced_id = @node_b.client.sendrawtransaction(psbt['hex'])

    # puts "tx_1: #{ @tx_1_id }"
    # puts "tx_2: #{ @tx_2_id }"
    # puts "tx_3: #{ @tx_3_id } -> #{ @tx_3_bumped_id }"
    # puts "tx_4: #{ @tx_4_id } -> #{ @tx_4_replaced_id }"

    @node_a.client.generate(2)
    @node_b.client.generate(2) # alternative chain with same length
    @node_a.poll!
    @node_b.poll!
    @node_a.reload
    expect(@node_a.block.height).to eq(@node_b.block.height)
    expect(@node_a.block.block_hash).not_to eq(@node_b.block.block_hash)
    test.connect_nodes(0, 1)
    # Don't sync, because there's no winning chain, so test framework times out
    # test.sync_blocks()

    allow(Block).to(receive(:find_by).and_wrap_original do |m, *args|
      block = m.call(*args)
      unless block.nil?
        allow(block).to receive(:first_seen_by).and_return block.first_seen_by_id == @node_a.id ? @node_a : @node_b
      end
      block
    end)
  end

  after do
    test.shutdown
  end

  describe 'find_or_generate' do
    it 'creates StaleCandidate' do
      s = described_class.find_or_generate(105)
      expect(s).not_to be_nil
      s.prime_cache
      expect(s.n_children).to eq(2)
    end

    it 'adds transactions' do
      described_class.find_or_generate(105)
      # Node A block 105 should contain tx_1, tx_2, tx_3 (bumped) and  tx_4 (bumped)
      block = Block.find_by!(height: 105, first_seen_by: @node_a)
      expect(block.transactions.where(is_coinbase: false).count).to eq(4)

      # Node B block 105 should only contain tx_1, tx_3 and tx_4
      block = Block.find_by!(height: 105, first_seen_by: @node_b)
      expect(block.transactions.where(is_coinbase: false).count).to eq(3)
    end
  end

  describe 'get_spent_coins_with_tx' do
    before do
      @s = described_class.find_or_generate(105)
      @s.fetch_transactions_for_descendants!
      @s.set_children!
    end

    it 'returns tx ids for long and short side' do
      res = @s.get_spent_coins_with_tx
      expect(res).not_to be_nil
      # Chains are equal length, so the result will be arbitrary depending
      # on details of the chain. This can cause a local test to pass while the
      # CI test fails. Note that the number of transactions is unrelated to
      # the length of the chain. We just use txs.length to get deterministic behavior.
      shortest_tx_ids, longest_tx_ids = res.sort_by(&:length)
      expect(longest_tx_ids.values.collect(&:tx_id).sort).to eq(
        [@tx_1_id, @tx_2_id, @tx_3_bumped_id, @tx_4_id].sort
      )
      expect(shortest_tx_ids.values.collect(&:tx_id).sort).to eq(
        [@tx_1_id, @tx_3_id, @tx_4_replaced_id].sort
      )
    end
  end

  describe 'set_conflicting_tx_info!' do
    before do
      @s = described_class.find_or_generate(105)
      expect(@s).not_to be_nil
      @s.fetch_transactions_for_descendants!
      @s.set_children!
      @s.set_conflicting_tx_info!(@node_a.block.height)
    end

    describe 'confirmed_in_one_branch' do
      it 'contains tx_2, tx_3&4 and bumped tx_3&4' do
        expect(@s.confirmed_in_one_branch.count).to eq(5)
        expect(@s.confirmed_in_one_branch).to include(@tx_2_id)
        expect(@s.confirmed_in_one_branch).to include(@tx_3_id)
        expect(@s.confirmed_in_one_branch).to include(@tx_3_bumped_id)
        expect(@s.confirmed_in_one_branch).to include(@tx_4_id)
        expect(@s.confirmed_in_one_branch).to include(@tx_4_replaced_id)
      end

      describe 'when one chain is longer' do
        before do
          test.disconnect_nodes(0, 1)
          expect(@node_a.client.getpeerinfo.count).to eq(0)
          # this mines tx_2
          @node_a.client.generate(1)
          @node_a.poll!
          @s.fetch_transactions_for_descendants!
          @s.set_children!
          @s.set_conflicting_tx_info!(@node_a.block.height)
        end

        it 'contains original tx_3 and replaced tx_4' do
          expect(@s.confirmed_in_one_branch.count).to eq(2)
          expect(@s.confirmed_in_one_branch).to include(@tx_3_id)
          expect(@s.confirmed_in_one_branch).to include(@tx_4_replaced_id)
        end
      end
    end

    describe 'rbf' do
      it 'contains tx_3 bumped' do
        # It picks an arbitrary "shortest" chain when both are the same length
        expect(@s.rbf.count).to eq(1)
        expect([@tx_3_id, @tx_3_bumped_id]).to include(@s.rbf[0])
      end

      describe 'when one chain is longer' do
        before do
          test.disconnect_nodes(0, 1)
          expect(@node_a.client.getpeerinfo.count).to eq(0)
          # this mines tx_2
          @node_a.client.generate(1)
          @node_a.poll!
          @s.fetch_transactions_for_descendants!
          @s.set_children!
          @s.set_conflicting_tx_info!(@node_a.block.height)
        end

        it 'contains tx_3' do
          expect(@s.rbf.count).to eq(1)
          expect(@s.rbf).to include(@tx_3_id)
        end

        it 'tracks replacement' do
          expect(@s.rbf_by.count).to eq(1)
          expect(@s.rbf_by).to include(@tx_3_bumped_id)
        end
      end
    end
  end

  describe 'self.check!' do
    let(:user) { create(:user) }

    before do
      allow(User).to receive_message_chain(:all, :find_each).and_yield(user)
    end

    it 'triggers potential stale block alert' do
      # One alert for the lowest height:
      expect { described_class.check! }.to(change { ActionMailer::Base.deliveries.count }.by(1))
      # Just once...
      expect { described_class.check! }.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it 'is quiet at an invalid block alert' do
      InvalidBlock.create(block: @node_a.block, node: @node_a)
      expect { described_class.check! }.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it 'is quiet after an invalid block alert' do
      InvalidBlock.create(block: @node_a.block.parent, node: @node_a)
      expect { described_class.check! }.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it 'notifies again if alert was dismissed' do
      InvalidBlock.create(block: @node_a.block.parent, node: @node_a, dismissed_at: Time.zone.now)
      expect { described_class.check! }.to(change { ActionMailer::Base.deliveries.count }.by(1))
    end

    it 'works for headers_only block' do
      @node_b.block.update headers_only: true, pool: nil, tx_count: nil, timestamp: nil, work: nil, parent_id: nil,
                           mediantime: nil, first_seen_by_id: nil
      expect { described_class.check! }.to(change { ActionMailer::Base.deliveries.count }.by(1))
    end

    it 'does not also create one if the race continues 1 more block' do
      test.disconnect_nodes(0, 1)
      expect(@node_a.client.getpeerinfo.count).to eq(0)
      @node_a.client.generate(1)
      @node_b.client.generate(1)
      @node_a.poll!
      @node_b.poll!
      @node_a.reload
      expect(@node_a.block.height).to eq(@node_b.block.height)
      expect(@node_a.block.block_hash).not_to eq(@node_b.block.block_hash)
      test.connect_nodes(0, 1)

      expect { described_class.check! }.to(change { ActionMailer::Base.deliveries.count }.by(1))
    end
  end

  describe 'self.process!' do
    before do
      described_class.check! # Create stale candidate entry at height 105
      expect(described_class.count).to eq(1)
      expect(described_class.first.height).to eq(105)
      described_class.process! # Fetch transactions from descendant blocks
    end

    it 'adds transactions for descendant blocks' do
      # Make node B chain win:
      @node_b.client.generate(1) # 105
      test.sync_blocks

      # Transaction 2 should be in mempool A now, but it won't broadcast
      @node_a.client.sendrawtransaction(@tx_2_raw)
      test.sync_mempools
      # Transaction 2 should be in the new block
      @node_a.client.generate(1) # 108
      test.sync_blocks

      @node_a.poll!
      @node_b.poll!

      described_class.process! # Fetch transactions from descendant blocks
      # Node B block 108 should contain tx_2
      block = Block.find_by!(height: 108)
      expect(block.transactions.where(is_coinbase: false).count).to eq(1)
    end

    it 'stops adding transactions after N descendant blocks' do
      # Make node B chain win:
      @node_b.client.generate(11)
      test.sync_blocks

      # Transaction 2 should be in mempool A now, but it won't broadcast
      @node_a.client.sendrawtransaction(@tx_2_raw)
      test.sync_mempools
      # Transaction 2 should be in the new block
      @node_a.client.generate(1) # 116
      test.sync_blocks

      @node_a.poll!
      @node_b.poll!

      described_class.process! # Fetch transactions from descendant blocks
      # Node B block 118 should contain tx_2
      block = Block.find_by!(height: 118)
      expect(block.transactions.where(is_coinbase: false).count).to eq(0)
    end
  end
end
