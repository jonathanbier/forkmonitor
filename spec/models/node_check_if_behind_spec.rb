# frozen_string_literal: true

require 'rails_helper'
require 'bitcoind_helper'

RSpec.describe Node, type: :model do
  let(:test) { TestWrapper.new }

  describe 'check_if_behind!' do
    after do
      test.shutdown
    end

    before do
      # Two nodes at the same height
      test.setup(num_nodes: 2)
      @node_a = create(:node_python)
      @node_a.client.set_python_node(test.nodes[0])
      @node_a.client.createwallet
      @node_a.client.generate(2)

      @node_b = create(:node_python)
      @node_b.client.set_python_node(test.nodes[1])
      @node_b.client.createwallet

      test.sync_blocks
    end

    it 'detects if node A and B are at the same block' do
      expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
    end

    describe 'when behind' do
      let(:user) { create(:user) }

      before do
        allow(described_class).to receive('set_pool_tx_ids_fee_total_for_block!').and_return(nil)

        test.disconnect_nodes(0, 1)
        assert_equal(0, @node_a.client.getpeerinfo.count)

        @node_b.client.generate(1)
        allow(described_class).to receive(:bitcoin_core_by_version).and_return [@node_a, @node_b]

        described_class.poll!
        @node_a.peer_count = 1 # Bypass peer check in check_if_behind!
        @first_check = @node_a.check_if_behind!(@node_b)
        Timecop.freeze(Time.zone.now + 15 * 60)

        allow(User).to receive_message_chain(:all, :find_each).and_yield(user)
      end

      it 'is false if the difference is recent' do
        expect(@first_check).to eq(false)
      end

      it 'detects if node A is behind node B' do
        lag = @node_a.check_if_behind!(@node_b)
        expect(lag).not_to be_nil
        expect(lag.node_a).to eq(@node_a)
        expect(lag.node_b).to eq(@node_b)
      end

      it 'is nil if the node is unreachable' do
        @node_a.update unreachable_since: Time.zone.now
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
      end

      it 'is nil if the node is in initial block download' do
        @node_a.update ibd: true
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
      end

      it 'is nil if other node is in initial block download' do
        @node_b.update ibd: true
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
      end

      it 'is nil if the node has no peers' do
        @node_a.peer_count = 0
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
      end

      it 'allows extra blocks for old nodes' do
        @node_a.update version: 100_300
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)
        @node_b.client.generate(3)
        described_class.poll!
        @node_a.update peer_count: 1, version: 100_300 # Undo override from poll
        expect(@node_a.check_if_behind!(@node_b)).not_to eq(nil)
      end

      it 'detects if bcoin node A is behind (core) node B' do
        @node_a.update version: '2.0.0'
        @node_a.update client_type: :bcoin

        lag = @node_a.check_if_behind!(@node_b)
        expect(lag).not_to be_nil
        expect(lag.node_a).to eq(@node_a)
        expect(lag.node_b).to eq(@node_b)
      end

      it 'allows extra blocks for btcd' do
        @node_a.update client_type: :btcd, version: 120_000
        expect(@node_a.check_if_behind!(@node_b)).to eq(nil)

        @node_b.client.generate(2)
        @node_a.update client_type: :core, version: 170_000 # Poll should use core
        described_class.poll!
        @node_a.update peer_count: 1, client_type: :btcd, version: 120_000
        expect(@node_a.check_if_behind!(@node_b)).not_to eq(nil)
      end

      it 'sends an email to all users' do
        expect { @node_a.check_if_behind!(@node_b) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it 'sends email only once' do
        expect { @node_a.check_if_behind!(@node_b) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect { @node_a.check_if_behind!(@node_b) }.to change { ActionMailer::Base.deliveries.count }.by(0)
      end
    end
  end
end
