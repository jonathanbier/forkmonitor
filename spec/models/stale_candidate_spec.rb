require "rails_helper"
require "bitcoind_helper"

RSpec.describe StaleCandidate, :type => :model do
  let(:test) { TestWrapper.new() }

  before do
    stub_const("BitcoinClient::Error", BitcoinClientMock::Error)
    stub_const("BitcoinClient::ConnectionError", BitcoinClientPython::ConnectionError)
    stub_const("BitcoinClient::PartialFileError", BitcoinClientPython::PartialFileError)
    stub_const("BitcoinClient::BlockPrunedError", BitcoinClientPython::BlockPrunedError)

    allow(Node).to receive("set_pool_for_block!").and_return(nil)
    test.setup(num_nodes: 2)
    @nodeA = create(:node_python)
    @nodeA.client.set_python_node(test.nodes[0])
    @nodeA.client.generate(2)

    @nodeB = create(:node_python)
    @nodeB.client.set_python_node(test.nodes[1])

    test.sync_blocks()

    test.disconnect_nodes(@nodeA.client, 1)
    assert_equal(0, @nodeA.client.getpeerinfo().count)

    @nodeA.client.generate(2)
    @nodeB.client.generate(2) # alternative chain with same length
    @nodeA.poll!
    @nodeB.poll!
    @nodeA.reload
    expect(@nodeA.block.height).to eq(@nodeB.block.height)
    expect(@nodeA.block.block_hash).not_to eq(@nodeB.block.block_hash)
    test.connect_nodes(@nodeA.client, 1)
    # Don't sync, as the test framework will time out
    # test.sync_blocks()
  end

  after do
    test.shutdown()
  end

  describe "self.check!" do
    let(:user) { create(:user) }

    before do
      allow(User).to receive(:all).twice.and_return [user]
    end

    it "should trigger potential stale block alert" do
      expect(User).to receive(:all).twice.and_return [user]

      # One alert for each height:
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(2)
      # Just once...
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "should be quiet at an invalid block alert" do
      i = InvalidBlock.create(block: @nodeA.block, node: @nodeA)
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "should be quiet after an invalid block alert" do
      i = InvalidBlock.create(block: @nodeA.block.parent, node: @nodeA)
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "should notify again if alert was dismissed" do
      InvalidBlock.create(block: @nodeA.block.parent, node: @nodeA, dismissed_at: Time.now)
      expect { StaleCandidate.check!(:btc) }.to change { ActionMailer::Base.deliveries.count }.by(2)
    end
  end

end
