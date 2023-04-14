# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserMailer do
  describe 'lag notify' do
    let(:user) { create(:user) }
    let(:lag) { create(:lag) }
    let(:mail) { described_class.with(user: user, lag: lag).lag_email }

    it 'renders the headers' do
      expect(mail.subject).to eq('[ForkMonitor] Bitcoin Core 0.10.3 is 1 blocks behind 230000')
      expect(mail.to).to eq([user.email])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include('https://forkmonitor.info/nodes/btc')
    end
  end

  describe 'invalid block notify' do
    let(:user) { create(:user) }
    let(:invalid_block) { create(:invalid_block) }
    let(:node_2) { create(:node_with_block, version: 160_300) }
    let(:mail) { described_class.with(user: user, invalid_block: invalid_block).invalid_block_email }

    before do
      invalid_block.block.update first_seen_by: node_2, marked_valid_by: [node_2.id]
    end

    it 'renders the headers' do
      expect(mail.subject).to eq("[ForkMonitor] Bitcoin Core 23.0 considers block #{invalid_block.block.height} (#{invalid_block.block.block_hash}) invalid")
      expect(mail.to).to eq([user.email])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include('https://forkmonitor.info/nodes/btc')
    end

    it 'mentions which node first saw the block' do
      expect(mail.body.encoded).to include('Bitcoin Core 0.16.3')
    end
  end

  describe 'version bits notify' do
    let(:user) { create(:user) }
    let(:node) { create(:node_with_block) }
    let(:mail) { described_class.with(user: user, bit: 1, tally: 2, window: 3, block: node.block).version_bits_email }

    it 'renders the headers' do
      expect(mail.subject).to eq("[ForkMonitor] version bit 1 was set 2 times between blocks #{node.block.height - 2} and #{node.block.height}")
      expect(mail.to).to eq([user.email])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include('https://forkmonitor.info/nodes/btc')
    end
  end

  describe 'stale candidate notify' do
    let(:user) { create(:user) }
    let(:mail) { described_class.with(user: user, stale_candidate: stale_candidate).stale_candidate_email }
    let(:stale_candidate) { create(:stale_candidate, height: 500_000) }

    before do
      @block_1 = create(:block, height: 500_000)
      @block_2 = create(:block, height: 500_000)
    end

    it 'renders the headers' do
      expect(mail.subject).to eq("[ForkMonitor] potential stale block at height #{stale_candidate.height}")
      expect(mail.to).to eq([user.email])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include(@block_1.block_hash)
      expect(mail.body.encoded).to include(@block_2.block_hash)
    end
  end
end
