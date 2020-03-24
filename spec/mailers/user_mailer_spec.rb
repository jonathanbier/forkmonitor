require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "lag notify" do
    let(:user) { create(:user) }
    let(:lag) { create(:lag) }
    let(:mail) { UserMailer.with(user: user, lag: lag).lag_email }

    it "renders the headers" do
      expect(mail.subject).to eq("[ForkMonitor] Bitcoin Core 0.10.3 is 1 blocks behind 170100")
      expect(mail.to).to eq([user.email])
    end

    it "renders the body" do
      expect(mail.body.encoded).to include("https://forkmonitor.info/nodes/btc")
    end

    it "links to the right coin" do
      lag.node_a.update coin: :bch
      lag.node_b.update coin: :bch
      expect(mail.body.encoded).to include("https://forkmonitor.info/nodes/bch")
    end
  end

  describe "invalid block notify" do
    let(:user) { create(:user) }
    let(:invalid_block) { create(:invalid_block) }
    let(:node2) { create(:node_with_block, version: 160300) }
    let(:mail) { UserMailer.with(user: user, invalid_block: invalid_block).invalid_block_email }

    before do
      invalid_block.block.update first_seen_by: node2, marked_valid_by: [node2.id]
    end

    it "renders the headers" do
      expect(mail.subject).to eq("[ForkMonitor] Bitcoin Core 0.17.1 considers BTC block #{ invalid_block.block.height } (#{ invalid_block.block.block_hash }) invalid")
      expect(mail.to).to eq([user.email])
    end

    it "renders the body" do
      expect(mail.body.encoded).to include("https://forkmonitor.info/nodes/btc")
    end

    it "mentions which node first saw the block" do
      expect(mail.body.encoded).to include("Bitcoin Core 0.16.3")
    end

  end

  describe "version bits notify" do
    let(:user) { create(:user) }
    let(:node ) { create(:node_with_block,) }
    let(:mail) { UserMailer.with(user: user, bit: 1, tally: 2, window: 3, block: node.block).version_bits_email }

    it "renders the headers" do
      expect(mail.subject).to eq("[ForkMonitor] version bit 1 was set 2 times between blocks #{ node.block.height - 2} and #{ node.block.height }")
      expect(mail.to).to eq([user.email])
    end

    it "renders the body" do
      expect(mail.body.encoded).to include("https://forkmonitor.info/nodes/btc")
    end

  end

  describe "stale candidate notify" do
    let(:user) { create(:user) }
    let(:stale_candidate) { create(:stale_candidate, coin: :btc, height: 500000) }
    before do
      @block1 = create(:block, height: 500000)
      @block2 = create(:block, height: 500000)
    end

    let(:mail) { UserMailer.with(user: user, stale_candidate: stale_candidate).stale_candidate_email }

    it "renders the headers" do
      expect(mail.subject).to eq("[ForkMonitor] potential BTC stale block at height #{ stale_candidate.height }")
      expect(mail.to).to eq([user.email])
    end

    it "renders the body" do
      expect(mail.body.encoded).to include(@block1.block_hash)
      expect(mail.body.encoded).to include(@block2.block_hash)
    end

  end
end
