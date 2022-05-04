# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvalidBlock, type: :model do
  describe 'InvalidBlock.check!' do
    let(:user) { create(:user) }

    let(:node_a) { create(:node_with_block) }
    let(:node_b) { create(:node_with_block) }

    before do
      node_a.block.update marked_valid_by: [node_a.id], marked_invalid_by: [node_b.id]
      allow(User).to receive_message_chain(:all, :find_each).and_yield(user)
    end

    it 'stores an InvalidBlock entry' do
      described_class.check!(:btc)
      disputed_block = node_a.block
      expect(described_class.count).to eq(1)
      expect(described_class.first.block).to eq(disputed_block)
      expect(described_class.first.node).to eq(node_b)
    end

    it 'sends an email to all users' do
      expect { described_class.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it 'sends email only once' do
      expect { described_class.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect { described_class.check!(:btc) }.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it 'node should have invalid blocks' do
      described_class.check!(:btc)
      expect(node_b.invalid_blocks.count).to eq(1)
    end

    it 'node can not be deleleted' do
      described_class.check!(:btc)
      expect { node_b.destroy }.to raise_error ActiveRecord::DeleteRestrictionError
    end
  end
end
