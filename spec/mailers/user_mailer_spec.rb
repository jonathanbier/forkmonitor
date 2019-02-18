require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "lag notify" do
    let(:user) { create(:user) }
    let(:lag) { create(:lag) }
    let(:mail) { UserMailer.with(user: user, lag: lag).lag_email }

    it "renders the headers" do
      expect(mail.subject).to eq("[ForkMonitor] Bitcoin Core 100300 is 1 blocks behind 170100")
      expect(mail.to).to eq([user.email])
    end

    it "renders the body" do
      expect(mail.body.encoded).to include("https://forkmonitor.info/nodes/btc")
    end
  end

  describe "invalid block notify" do
    let(:user) { create(:user) }
    let(:invalid_block) { create(:invalid_block) }
    let(:mail) { UserMailer.with(user: user, invalid_block: invalid_block).invalid_block_email }

    it "renders the headers" do
      expect(mail.subject).to eq("[ForkMonitor] Bitcoin Core 170100 considers block #{ invalid_block.block.height } (#{ invalid_block.block.block_hash }) invalid")
      expect(mail.to).to eq([user.email])
    end

    it "renders the body" do
      expect(mail.body.encoded).to include("https://forkmonitor.info/nodes/btc")
    end
  end
end
