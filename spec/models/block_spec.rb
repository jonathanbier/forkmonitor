require "rails_helper"

RSpec.describe Block, :type => :model do
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

  describe "create_with" do
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
    end

    it "should store the version" do
      @block = Block.create_with(@block_info, false, @node, true)
      expect(@block.version).to eq(536870912)
    end

    it "should store number of transactions" do
      @block = Block.create_with(@block_info, false, @node, true)
      expect(@block.tx_count).to eq(3024)
    end

    it "should store size" do
      @block = Block.create_with(@block_info, false, @node, true)
      expect(@block.size).to eq(1328797)
    end

  end

  describe "self.pool_from_coinbase_tx" do
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

end
