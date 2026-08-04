# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Block do
  describe 'self.find_missing with an unresponsive mirror' do
    let!(:headers_only_block) { create(:block, headers_only: true) }
    let(:mirror_node) { instance_double(Node) }

    before do
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(Node).to receive(:bitcoin_core_by_version).and_return([])
      allow(Node).to receive(:with_mirror).and_return([mirror_node])
      allow(mirror_node).to receive(:getblockheader)
        .with(headers_only_block.block_hash, true, true)
        .and_raise(BitcoinUtil::RPC::TimeOutError, 'mirror timed out')
    end

    it 'returns control to the rollback checks' do
      expect(Rails.logger).to receive(:error).with('Timed out while finding missing blocks: mirror timed out')

      expect(described_class.find_missing(40_000, 0)).to be_nil
    end
  end
end
