require 'rails_helper'

RSpec.describe Softfork, type: :model do
  let(:node) { create(:node_with_block, version: 200000) }

  describe "process" do
    it "should do nothing if no forks are active" do
      blockchaininfo = {
        "chain" => "main",
        "softforks" => {
        }
      }
      Softfork.process(node, blockchaininfo)
      expect(Softfork.count).to eq(0)
    end

    it "should add an active bip9 softfork" do
      blockchaininfo = {
        "chain" => "main",
        "softforks" => {
          "segwit" => {
            "type" => "bip9",
            "bip9" => {
              "status" => "active",
              "bit" => 1,
              "height" => 481824
            }
          }
        }
      }
      Softfork.process(node, blockchaininfo)
      expect(Softfork.count).to eq(1)

      # And not more than once
      Softfork.process(node, blockchaininfo)
      expect(Softfork.count).to eq(1)
    end

    it "should handle a status update" do
      blockchaininfo = {
        "chain" => "main",
        "softforks" => {
          "segwit" => {
            "type" => "bip9",
            "bip9" => {
              "status" => "defined",
              "bit" => 1,
              "height" => 470000
            }
          }
        }
      }
      Softfork.process(node, blockchaininfo)
      expect(Softfork.count).to eq(1)
      expect(Softfork.first.status).to eq("defined")

      blockchaininfo = {
        "chain" => "main",
        "softforks" => {
          "segwit" => {
            "type" => "bip9",
            "bip9" => {
              "status" => "active",
              "bit" => 1,
              "height" => 481824
            }
          }
        }
      }
      Softfork.process(node, blockchaininfo)
      expect(Softfork.count).to eq(1)
      expect(Softfork.first.status).to eq("active")
    end

    it "should parse pre 0.19 format" do
      node.version = 180100
      blockchaininfo = {
        "chain" => "main",
        "bip9_softforks" => {
          "segwit" => {
            "status" => "active",
            "height" => 481824
          }
        }
      }
      Softfork.process(node, blockchaininfo)
      expect(Softfork.count).to eq(1)

      # And not more than once
      Softfork.process(node, blockchaininfo)
      expect(Softfork.count).to eq(1)
    end

    it "should ignore burried softforks" do
      blockchaininfo = {
        "chain" => "main",
        "softforks" => {
          "bip66" => {
            "type" => "buried",
            "active" => true,
            "height" => 363725
          },
        }
      }
      Softfork.process(node, blockchaininfo)
      expect(Softfork.count).to eq(0)
    end
  end
end
