require 'rails_helper'

RSpec.describe BlockTemplate, type: :model do
  describe "transaction hashes to binary" do
    it "should go both ways" do
      tx_hashes = [
        "9881370ee1013f336e4b4b98b4fc5caf8f0e0f7582f19b1b14ca39058f48cb7a",
        "e4b2e88a3122dcae3f7c593461cd7fc508dff2363c8a7195b49168ba0fe7b52f"
      ]
      binary = BlockTemplate.hashes_to_binary(tx_hashes)
      expect(BlockTemplate.binary_to_hashes(binary)).to eq(tx_hashes)
    end
  end
end
