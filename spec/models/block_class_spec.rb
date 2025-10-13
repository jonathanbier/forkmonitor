# frozen_string_literal: true

require 'rails_helper'
require 'bitcoind_helper'

RSpec.describe Block do
  let(:test) { new_test_wrapper }

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

    allow(Node).to receive(:with_mirror).and_return [@node_a]
    allow(Node).to receive(:bitcoin_core_by_version).and_return [@node_a, @node_b]
  end

  after do
    test.shutdown if @use_python_nodes
  end

  describe 'self.pool_from_coinbase_tx' do
    before do
      create(:antpool)
      create(:f2pool)
    end

    it 'finds Antpool' do
      # response from getrawtransaction 99d1ead20f83d090f2878559446abaa5db320524f63011ed1b71bfef47c5ac02 true
      tx = {
        'txid' => '99d1ead20f83d090f2878559446abaa5db320524f63011ed1b71bfef47c5ac02',
        'hash' => 'b1bf7d584467258e368199d9851e820176bf06f2208f1e2ec6433f21eac5842d',
        'version' => 1,
        'size' => 252,
        'vsize' => 225,
        'weight' => 900,
        'locktime' => 0,
        'vin' => [
          {
            'coinbase' => '0375e8081b4d696e656420627920416e74506f6f6c34381d00330020c85d207ffabe6d6d2bcb43e33b12c011f5e99afe1b4478d1001b7ce90db6b7c937793e89fafae6dd040000000000000052000000eb0b0200',
            'sequence' => 4_294_967_295
          }
        ],
        'vout' => [
          {
            'value' => 13.31801952,
            'n' => 0,
            'scriptPubKey' => {
              'asm' => 'OP_DUP OP_HASH160 edf10a7fac6b32e24daa5305c723f3de58db1bc8 OP_EQUALVERIFY OP_CHECKSIG', 'hex' => '76a914edf10a7fac6b32e24daa5305c723f3de58db1bc888ac', 'reqSigs' => 1, 'type' => 'pubkeyhash', 'addresses' => ['1Nh7uHdvY6fNwtQtM1G5EZAFPLC33B59rB']
            }
          }, {
            'value' => 0.0,
            'n' => 1,
            'scriptPubKey' => {
              'asm' => 'OP_RETURN aa21a9ed53112dcef82ee73de0243da1fe7278468349c7098fa3db778383005238d28e0a', 'hex' => '6a24aa21a9ed53112dcef82ee73de0243da1fe7278468349c7098fa3db778383005238d28e0a', 'type' => 'nulldata'
            }
          }
        ], 'hex' => '010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff540375e8081b4d696e656420627920416e74506f6f6c34381d00330020c85d207ffabe6d6d2bcb43e33b12c011f5e99afe1b4478d1001b7ce90db6b7c937793e89fafae6dd040000000000000052000000eb0b0200ffffffff0260af614f000000001976a914edf10a7fac6b32e24daa5305c723f3de58db1bc888ac0000000000000000266a24aa21a9ed53112dcef82ee73de0243da1fe7278468349c7098fa3db778383005238d28e0a0120000000000000000000000000000000000000000000000000000000000000000000000000',
        'blockhash' => '0000000000000000001e93e79aa71bec43c72d671935e704b0713a4453e04183',
        'confirmations' => 14,
        'time' => 1_562_242_070,
        'blocktime' => 1_562_242_070
      }

      expect(described_class.pool_from_coinbase_tx(tx)).to eq('Antpool')
    end

    it 'finds F2Pool' do
      # Truncated response from getrawtransaction 87b72be71eab3fb8c452ea91ba0c21c4b9affa56386b0455ad50d3513c433484 true
      tx = {
        'vin' => [
          {
            'coinbase' => '039de8082cfabe6d6db6e2235d03234641c5859b7b1864addea7c0c2ef07a68bb8ebc178ac804f4b6910000000f09f909f000f4d696e656420627920776c3337373100000000000000000000000000000000000000000000000000000000050024c5aa2a',
            'sequence' => 0
          }
        ]
      }

      expect(described_class.pool_from_coinbase_tx(tx)).to eq('F2Pool')
    end
  end

  describe 'self.create_headers_only' do
    before do
      @node = build(:node)
    end

    it 'marks block as headers_only' do
      block = described_class.create_headers_only(@node, 560_182,
                                                  '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377')
      expect(block.headers_only).to be(true)
    end

    it 'sets first seen by' do
      block = described_class.create_headers_only(@node, 560_182,
                                                  '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377')
      expect(block.first_seen_by).to eq(@node)
    end

    it 'is updated by find_or_create_by' do
      allow(Node).to receive('set_pool_for_block!').and_return(nil)
      block = described_class.create_headers_only(@node, 560_182,
                                                  '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377')
      described_class.create_or_update_with({
                                              'hash' => '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377',
                                              'height' => 560_182,
                                              'nTx' => 3
                                            }, false, @node, nil)
      block.reload
      expect(block.headers_only).to be(false)
      expect(block.tx_count).to eq(3)
    end

    it 'has a valid summary' do
      block = described_class.create_headers_only(@node, 560_182,
                                                  '0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377')
      expect(block.summary(time: true,
                           first_seen_by: true)).to eq('0000000000000000002593e1504eb5c5813cac4657d78a04d81ff4e2250d3377 (10:57:31 by unknown pool, first seen by Bitcoin Core 23.0)')
    end
  end

  describe 'self.find_missing' do
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
      test.connect_nodes(0, 1)
      test.connect_nodes(0, 2)
      test.connect_nodes(1, 2)

      test.sync_blocks

      chaintips_a = @node_a.client.getchaintips

      expect(chaintips_a.length).to eq(2)
      expect(chaintips_a[-1]['status']).to eq('headers-only')

      Chaintip.check!([@node_a])
      @headers_only_block = described_class.find_by(block_hash: chaintips_a[-1]['hash'])
      expect(@headers_only_block.headers_only).to be(true)
    end

    it 'obtains block from other node if available' do
      described_class.find_missing(1, 1)
      @headers_only_block.reload
      expect(@headers_only_block.headers_only).to be(false)
      expect(@headers_only_block.first_seen_by).to eq(@node_b)
    end

    it 'submits block to original node' do
      expect do
        @node_a.client.getblock(@headers_only_block.block_hash, 1)
      end.to raise_error(BitcoinUtil::RPC::BlockNotFoundError)
      described_class.find_missing(1, 1)
      res = @node_a.client.getblock(@headers_only_block.block_hash, 1)
      expect(res['confirmations']).to eq(-1)
    end
  end
end
