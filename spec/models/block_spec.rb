# frozen_string_literal: true

require 'rails_helper'
require 'bitcoind_helper'

RSpec.describe Block, type: :model do
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
    assert_equal(@node_a.block.height, 2)
    assert_equal(@node_a.mirror_block.height, 2)

    @node_b.poll!
    @node_b.reload
    assert_equal(@node_b.block.height, 2)

    assert_equal(Chaintip.count, 0)

    allow(Node).to receive(:with_mirror).with(:btc).and_return [@node_a]
    allow(Node).to receive(:bitcoin_core_by_version).and_return [@node_a, @node_b]
  end

  after do
    test.shutdown if @use_python_nodes
  end

  describe 'log2_pow' do
    it 'is log2(pow)' do
      block = create(:block, work: '00000000000000000000000000000001')
      expect(block.log2_pow).to eq(0.0)
      block = create(:block, work: '00000000000000000000000000000002')
      expect(block.log2_pow).to eq(1.0)
    end
  end

  describe 'summary' do
    it 'shows the pool' do
      block = create(:block, pool: 'Antpool')
      expect(block.summary).to include('Antpool')
    end

    it "shows 'unknown pool'" do
      block = create(:block, pool: nil)
      expect(block.summary).to include('unknown pool')
    end

    it 'includes the block size in MB' do
      block = create(:block, pool: 'Antpool', size: 300_000)
      expect(block.summary).to include('0.3 MB')
    end

    it 'rounds the block size to two decimals' do
      block = create(:block, pool: 'Antpool', size: 289_999)
      expect(block.summary).to include('0.29 MB')
    end

    it 'shows time of day if requested' do
      block = create(:block, pool: nil, size: nil, timestamp: 1_566_575_008)
      expect(block.summary(time: true)).to include('(15:43:28')
    end

    it 'does not show time of day if timestamp field is missing' do
      block = create(:block, pool: nil, size: nil, timestamp: nil)
      expect(block.summary(time: true)).not_to include('(15:43:28')
    end

    it 'uses interpunction' do
      block = create(:block, block_hash: '0000000', pool: 'Antpool', size: 289_999, timestamp: 1_566_575_008)
      expect(block.summary).to eq('0000000 (0.29 MB, Antpool)')
      expect(block.summary(time: true)).to eq('0000000 (0.29 MB, 15:43:28 by Antpool)')
      block.pool = nil
      expect(block.summary(time: true)).to eq('0000000 (0.29 MB, 15:43:28 by unknown pool)')
      block.size = nil
      expect(block.summary).to eq('0000000 (unknown pool)')
    end

    it 'shows first seen by if requested' do
      block = create(:block, pool: nil, first_seen_by: build(:node))
      expect(block.summary(first_seen_by: true)).to include('first seen by Bitcoin Core 23.0')
    end

    it 'does not show first seen by if unknown' do
      block = create(:block, pool: nil, first_seen_by: nil)
      expect(block.summary(first_seen_by: true)).not_to include('first seen by Bitcoin Core 23.0')
    end
  end

  describe 'version_bits' do
    it 'is empty by default' do
      block = create(:block)
      expect(block.version_bits).to eq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                        0, 0, 0])
    end

    it 'detects bit 1' do
      block = create(:block, version: 0x20000001)
      expect(block.version_bits).to eq([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                        0, 0, 0])
    end
  end

  describe 'maximum_inflation' do
    it 'is 12.5 for BTC in mid 2019' do
      @block = build(:block, height: 596_808)
      expect(@block.max_inflation).to eq(12.5 * Block::COIN)
    end

    it 'is 50 for BTC in 2009' do
      @block = build(:block, height: 100)
      expect(@block.max_inflation).to eq(50 * Block::COIN)
    end

    it 'is 12.5 for BTC immediately before the 2020 halving' do
      @block = build(:block, height: 629_999)
      expect(@block.max_inflation).to eq(12.5 * Block::COIN)
    end

    it 'is 6.25 for BTC at the 2020 halving' do
      @block = build(:block, height: 630_000)
      expect(@block.max_inflation).to eq(6.25 * Block::COIN)
    end

    it 'is 0.00000009 for BTC at height 6090000' do
      @block = build(:block, height: 6_090_000)
      expect(@block.max_inflation).to eq(0.00000009 * Block::COIN)
    end

    it 'is 0 for BTC as of height 6930000' do
      @block = build(:block, height: 6_930_000)
      expect(@block.max_inflation).to eq(0.00000000 * Block::COIN)
    end

    it 'creates slightly less than 21 million BTC' do
      @block = build(:block, height: 0)
      i = 0
      coins = 0.0
      while i < 10_000_000
        @block.height = i
        coins += 1000 * @block.max_inflation
        i += 1000
      end
      expect(coins).to eq(20_999_999.9769 * Block::COIN)
    end
  end

  describe 'descendants' do
    before do
      # A -> B1 -> C1 -> D1
      #   -> B2
      @a = create(:block)
      @b_1 = create(:block, parent: @a)
      @b_2 = create(:block, parent: @a)
      @c_1 = create(:block, parent: @b_1)
      @d_1 = create(:block, parent: @c_1)
    end

    it 'does not return itself' do
      expect(@a.descendants).not_to include(@a)
    end

    it 'returns all blocks descending' do
      expect(@b_1.descendants).to include(@c_1)
      expect(@b_1.descendants).to include(@d_1)
    end

    it "does not return blocks that don't descend from it" do
      expect(@b_2.descendants).not_to include(@c_1)
    end
  end

  describe 'branch_start' do
    before do
      # A -> B1 -> C1 -> D1
      #   -> B2 -> C2
      @a = create(:block)
      @b_1 = create(:block, parent: @a)
      @b_2 = create(:block, parent: @a)
      @c_1 = create(:block, parent: @b_1)
      @c_2 = create(:block, parent: @b_2)
      @d_1 = create(:block, parent: @c_1)
    end

    it 'fails if comparing to self' do
      expect { @a.branch_start(@a) }.to raise_error('same block')
    end

    it 'fails if comparing on same branch' do
      expect { @b_1.branch_start(@c_1) }.to raise_error('same branch')
      expect { @c_1.branch_start(@d_1) }.to raise_error('same branch')
    end

    it 'finds the branch start' do
      expect(@d_1.branch_start(@c_2)).to eq(@b_1)
      expect(@c_2.branch_start(@d_1)).to eq(@b_2)
    end
  end

  describe 'fetch_transactions!' do
    before do
      @node = create(:node)
    end

    it 'fetches transactions for the block' do
      expect(described_class).to receive(:find_by).and_call_original # Sanity check for later test
      @block = create(:block, block_hash: '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377',
                              first_seen_by: @node)
      @block.fetch_transactions! # Mock client knows one transaction for this block
      expect(@block.transactions.count).to eq(1)
    end

    it 'does not fetch twice' do
      expect(described_class).to receive(:find_by).once.and_call_original
      @block = create(:block, block_hash: '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377',
                              first_seen_by: @node)
      @block.fetch_transactions!
      @block.fetch_transactions!
      expect(@block.transactions.count).to eq(1)
    end

    it "marks block as pruned if it can't be fetched due to pruning" do
      @block = create(:block, block_hash: '0000000000000000000000000000000000000000000000000000000000000001',
                              first_seen_by: @node)
      @block.fetch_transactions!
      expect(@block.pruned).to be(true)
    end

    it 'tries the modern node if a block was pruned' do
      @block = create(:block, block_hash: '0000000000000000000000000000000000000000000000000000000000000001',
                              first_seen_by: @node)
      @block.fetch_transactions!
      expect(described_class).to receive(:find_by).and_call_original
      expect { @block.fetch_transactions! }.to raise_error Node::NoMatchingNodeError
    end
  end

  describe 'create_or_update_with' do
    before do
      @node = build(:node)
      @block_info = {
        'hash' => '000000000000000000063d6a38161b2a69ba6bfe84f31272ffc3c36308b55574',
        'confirmations' => 1,
        'strippedsize' => 889_912,
        'size' => 1_328_797,
        'weight' => 3_998_533,
        'height' => 584_492,
        'version' => 536_870_912,
        'versionHex' => '20000000',
        'merkleroot' => '32a561821430a709585266f9642a6dd808de59eea5b198497f577127b4a4e3e8',
        'tx' => [],
        'time' => 1_562_591_342,
        'mediantime' => 1_562_589_082,
        'nonce' => 663_397_958,
        'bits' => '1723792c',
        'difficulty' => 7_934_713_219_630.606,
        'chainwork' => '00000000000000000000000000000000000000000714a4cd58e70c3c61429c91',
        'nTx' => 3024,
        'previousblockhash' => '00000000000000000005b127b27cc0771e1b0fcb18dcba4c0644f2bb4dc90597'
      }
      allow(Node).to receive('set_pool_for_block!').and_return(nil)
    end

    it 'stores the version' do
      @block = described_class.create_or_update_with(@block_info, false, @node, true)
      expect(@block.version).to eq(536_870_912)
    end

    it 'stores number of transactions' do
      @block = described_class.create_or_update_with(@block_info, false, @node, true)
      expect(@block.tx_count).to eq(3024)
    end

    it 'stores size' do
      @block = described_class.create_or_update_with(@block_info, false, @node, true)
      expect(@block.size).to eq(1_328_797)
    end
  end
end
