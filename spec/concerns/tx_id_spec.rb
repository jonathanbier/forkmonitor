require 'rails_helper'

describe TxIdConcern do
  describe "transaction hashes to binary" do
    let(:test_class) { Struct.new(:dummy) { include TxIdConcern } }
    it "should go both ways" do
      tx_hashes = [
        "9881370ee1013f336e4b4b98b4fc5caf8f0e0f7582f19b1b14ca39058f48cb7a",
        "e4b2e88a3122dcae3f7c593461cd7fc508dff2363c8a7195b49168ba0fe7b52f"
      ]
      binary = test_class.hashes_to_binary(tx_hashes)
      expect(test_class.binary_to_hashes(binary)).to eq(tx_hashes)
    end

    describe "get_binary_chunks" do
      it "should reject nil data" do
        expect { test_class.get_binary_chunks(nil, 2) }.to raise_error(TxIdConcern::NilError)
      end
    end

    describe "binary_to_hashes" do
      it "should reject nil binary" do
        expect { test_class.binary_to_hashes(nil) }.to raise_error(TxIdConcern::NilError)
      end
    end
  end
end
