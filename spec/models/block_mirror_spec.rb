# frozen_string_literal: true

require 'rails_helper'
require 'bitcoind_helper'

RSpec.describe Block do
  let(:test) { TestWrapper.new }

  def setup_python_nodes
    # Node A with mirror node, node B
    # Create two blocks and sync
    @use_python_nodes = true

    test.setup(num_nodes: 3, extra_args: [['-whitelist=noban@127.0.0.1']] * 3)
    @node_a = create(:node_python_with_mirror)
    @node_a.client.set_python_node(test.nodes[0])
    @node_a.mirror_client.set_python_node(test.nodes[1])

    @node_b = create(:node_python)
    @node_b.client.set_python_node(test.nodes[2])
    @node_a.client.generate(2)
    test.sync_blocks

    @node_a.poll!
    @node_a.poll_mirror!
    @node_a.reload
    expect(@node_a.block.height).to eq(2)
    expect(@node_a.mirror_block.height).to eq(2)

    @node_b.poll!
    @node_b.reload
    expect(@node_b.block.height).to eq(2)

    expect(Chaintip.count).to eq(0)

    allow(Node).to receive(:with_mirror).with(:btc).and_return [@node_a]
    allow(Node).to receive(:bitcoin_core_by_version).and_return [@node_a, @node_b]
  end

  after do
    test.shutdown if @use_python_nodes
  end

  describe 'make_active_on_mirror!' do
    before do
      setup_python_nodes

      test.disconnect_nodes(0, 1) # disconnect A from mirror (A')
      test.disconnect_nodes(0, 2) # disconnect A from B
      test.disconnect_nodes(1, 2) # disconnect A' from B
      expect(@node_a.client.getpeerinfo.count).to eq(0)
      expect(@node_a.mirror_client.getpeerinfo.count).to eq(0)

      @node_a.client.generate(1) # this active, but changes to valid-fork after reconnect
      @node_b.client.generate(2) # active one node B
      @node_a.poll!
      @node_b.poll!
      test.connect_nodes(0, 1)
      test.connect_nodes(0, 2)
      test.connect_nodes(1, 2)

      test.sync_blocks

      chaintips_a = @node_a.client.getchaintips
      Rails.logger.info chaintips_a

      expect(chaintips_a.length).to eq(2)
      expect(chaintips_a[-1]['status']).to eq('valid-fork')

      Chaintip.check!(:btc, [@node_a])
      @valid_fork_block = described_class.find_by(block_hash: chaintips_a[-1]['hash'])
    end

    it "changes the mirror's active chaintip" do
      @valid_fork_block.make_active_on_mirror!(@node_a)
      chaintips_a = @node_a.mirror_client.getchaintips
      expect(chaintips_a[1]['status']).to eq('active')
      expect(chaintips_a[1]['hash']).to eq(@valid_fork_block.block_hash)
    end
  end

  describe 'validate_fork!' do
    before do
      setup_python_nodes

      test.disconnect_nodes(0, 1) # disconnect A from mirror (A')
      test.disconnect_nodes(0, 2) # disconnect A from B
      test.disconnect_nodes(1, 2) # disconnect A' from B
      expect(@node_a.client.getpeerinfo.count).to eq(0)
      expect(@node_a.mirror_client.getpeerinfo.count).to eq(0)

      @node_a.client.generate(2) # this is and remains active
      @node_b.client.generate(1) # Node A will see this as valid-headers after reconnect
      @node_a.poll!
      @node_b.poll!
      test.connect_nodes(0, 1)
      test.connect_nodes(0, 2)
      test.connect_nodes(1, 2)

      test.sync_blocks

      chaintips_a = @node_a.client.getchaintips

      expect(chaintips_a.length).to eq(2)
      expect(chaintips_a[-1]['status']).to eq('headers-only')
      @block = described_class.find_by(block_hash: chaintips_a[-1]['hash'])
    end

    it 'skips if the node already marked it as (in)valid' do
      @block.update marked_valid_by: [@node_a.id]
      expect(@block).not_to receive(:make_active_on_mirror!)
      @block.validate_fork!(@node_a)
    end

    it "skips if the node doesn't have a mirror" do
      @node_a.update mirror_rpchost: nil
      expect(@block).not_to receive(:make_active_on_mirror!)
      @block.validate_fork!(@node_a)
    end

    it "skips if the mirror node doesn't have the block" do
      expect { @node_a.mirror_client.getblock(@block.block_hash, 1) }.to raise_error(BitcoinUtil::RPC::BlockNotFoundError)
    end

    describe 'when mirror client has block' do
      before do
        expect(@node_a.mirror_client.submitblock(@node_b.client.getblock(@block.block_hash, 0))).to eq('inconclusive')
      end

      it 'rolls the mirror back' do
        expect(@block).to receive(:make_active_on_mirror!).with(@node_a).and_call_original
        @block.validate_fork!(@node_a)
      end

      it 'marks the block as considered valid' do
        @block.validate_fork!(@node_a)
        expect(@block.marked_valid_by).to include(@node_a.id)
      end

      it 'rolls the mirror forward' do
        expect(@node_a.mirror_client).to receive(:reconsiderblock)
        @block.validate_fork!(@node_a)
      end
    end
  end
end
