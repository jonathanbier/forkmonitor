# frozen_string_literal: true

module MockNodeHelpers
  # Required variables:
  # test: TestWrapper
  def setup_chaintip_spec_nodes
    # TODO: figure out how to get the "send" RPC to work ('send' is a reserved
    # keyword in Ruby and Python and this seems to confuse the wrapper)
    #
    # Once a release with Taproot support is available, it's best to use that
    # for the second node, so that this test still works when Taproot deployment
    # is buried (at which point vbparams won't work).
    test.setup(num_nodes: 3, extra_args: [
                 [
                   '-walletbroadcast=0' # manually broadcast wallet transactions
                 ],
                 [
                   '-vbparams=taproot:0:0'
                 ],
                 []
               ])
    @node_a = create(:node_python) # Taproot enabled
    @node_a.client.set_python_node(test.nodes[0])
    @node_b = create(:node_python) # Taproot disabled
    @node_b.client.set_python_node(test.nodes[1])

    deployments = @node_b.client.getdeploymentinfo
    expect(deployments['deployments']['taproot']['active']).to be(false)

    @node_c = create(:node_python)
    @node_c.client.set_python_node(test.nodes[2])

    # Disconnect Node C so we can give it an independent chain
    @node_c.client.setnetworkactive(false)
    test.disconnect_nodes(0, 2)
    test.disconnect_nodes(1, 2)

    @node_a.client.createwallet(blank: true)
    @node_a.client.importdescriptors([
                                       {
                                         desc: 'tr(tprv8ZgxMBicQKsPeNLUGrbv3b7qhUk1LQJZAGMuk9gVuKh9sd4BWGp1eMsehUni6qGb8bjkdwBxCbgNGdh2bYGACK5C5dRTaif9KBKGVnSezxV/0/*)#c8796lse', active: true, internal: false, timestamp: 'now', range: 10
                                       },
                                       {
                                         desc: 'tr(tprv8ZgxMBicQKsPeNLUGrbv3b7qhUk1LQJZAGMuk9gVuKh9sd4BWGp1eMsehUni6qGb8bjkdwBxCbgNGdh2bYGACK5C5dRTaif9KBKGVnSezxV/1/*)#fnmy82qp', active: true, internal: true, timestamp: 'now', range: 10
                                       }
                                     ])
    @node_b.client.createwallet
    @addr_1 = @node_a.client.getnewaddress('bech32m') # Taproot address
    @addr_2 = @node_a.client.getnewaddress('bech32m') # Taproot address
    @r_addr = @node_b.client.getnewaddress('bech32m') # Taproot address

    # Mine enough blocks on node B to fund node A with confirmed taproot outputs
    @node_b.client.generatetoaddress(101, @r_addr)
    test.sync_blocks([@node_a.client, @node_b.client])

    funding_tx = @node_b.client.sendtoaddress(@addr_1, 1)
    expect(funding_tx).not_to be_nil

    @node_b.client.generatetoaddress(1, @r_addr)
    test.sync_blocks([@node_a.client, @node_b.client])

    @node_a.poll!
    @node_a.reload
    @initial_height = @node_a.block.height
    expect(@initial_height).to be >= 2
    expect(@node_a.block.parent).not_to be_nil
    expect(@node_a.block.parent.height).to eq(@initial_height - 1)
    expect(Chaintip.count).to eq(0)

    @node_b.poll!
    @node_b.reload
    expect(@node_b.block.height).to eq(@initial_height)
    expect(@node_b.block.parent.height).to eq(@initial_height - 1)
    expect(Chaintip.count).to eq(0)

    @node_c.client.createwallet
    @addr_3 = @node_c.client.getnewaddress
    @node_c.client.generatetoaddress(3, @addr_3) # longer chain than A and B, so it won't validate those blocks
    # Node C intentionally remains disconnected from A and B
  end
end
