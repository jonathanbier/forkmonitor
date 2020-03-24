require 'rails_helper'

RSpec.describe InvalidBlock, type: :model do
  describe "InvalidBlock.check!" do

    let(:user) { create(:user) }

    let(:nodeA) { create(:node_with_block) }
    let(:nodeB) { create(:node_with_block) }

    before do
      nodeA.block.update marked_valid_by: [nodeA.id], marked_invalid_by: [nodeB.id]
    end

    it "should store an InvalidBlock entry" do
      InvalidBlock.check!(:btc)
      disputed_block = nodeA.block
      expect(InvalidBlock.count).to eq(1)
      expect(InvalidBlock.first.block).to eq(disputed_block)
      expect(InvalidBlock.first.node).to eq(nodeB)
    end

    it "should send an email to all users" do
      expect(User).to receive(:all).and_return [user]
      expect { InvalidBlock.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "should send email only once" do
      expect(User).to receive(:all).and_return [user]
      expect { InvalidBlock.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect { InvalidBlock.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "node should have invalid blocks" do
      InvalidBlock.check!(:btc)
      expect(nodeB.invalid_blocks.count).to eq(1)
    end

    it "node can not be deleleted" do
      InvalidBlock.check!(:btc)
      expect { nodeB.destroy }.to raise_error ActiveRecord::DeleteRestrictionError
    end
  end
end
