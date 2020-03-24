require 'rails_helper'

RSpec.describe FeedsController, type: :controller do
  describe "RSS feed" do
    render_views

    describe "GET inflated_block feed" do
      let!(:inflated_block) { create(:inflated_block) }

      it "should be rendered" do
        get :inflated_blocks, params: {coin: "btc"}, format: :rss
        expect(response).to render_template("feeds/inflated_blocks")
        expect(response.body).to include("Inflated BTC blocks")
      end

      it "should contain inflated blocks" do
        get :inflated_blocks, params: {coin: "btc"}, format: :rss
        expect(response.body).to include("#{ inflated_block.actual_inflation - inflated_block.max_inflation } BTC")
      end
    end

    describe "GET blocks_invalid feed" do
      let!(:node) { create(:node) }
      let!(:block) { create(:block) }

      before do
        block.update marked_invalid_by: [node.id]
      end

      it "should be rendered" do
        get :blocks_invalid, params: {coin: "btc"}, format: :rss
        expect(response).to render_template("feeds/blocks_invalid")
        expect(response.body).to include("Invalid BTC blocks")
      end

      it "should contain invalid blocks" do
        get :blocks_invalid, params: {coin: "btc"}, format: :rss
        expect(response.body).to include(node.name_with_version)
      end
    end

    describe "GET invalid_block feed" do
      let!(:node) { create(:node) }
      let!(:invalid_block) { create(:invalid_block) }

      before do
        invalid_block.block.update marked_valid_by: [node.id]
      end

      it "should be rendered" do
        get :invalid_blocks, params: {coin: "btc"}, format: :rss
        expect(response).to render_template("feeds/invalid_blocks")
        expect(response.body).to include("Invalid BTC blocks")
      end

      it "should contain invalid blocks" do
        get :invalid_blocks, params: {coin: "btc"}, format: :rss
        expect(response.body).to include(invalid_block.node.name_with_version)
      end
    end

    describe "GET lagging_nodes feed" do
      let!(:lagging_node) { create(:lag) }

      it "should be rendered" do
        get :lagging_nodes, format: :rss
        expect(response).to render_template("feeds/lagging_nodes")
        expect(response.body).to include("behind")
      end

      it "should contain a lagging node" do
        get :lagging_nodes, format: :rss
        expect(response.body).to include(lagging_node.node_a.name_with_version)
      end
    end

    describe "GET version_bits feed" do
      let!(:version_bit) { create(:version_bit) }

      it "should be rendered" do
        get :version_bits, format: :rss
        expect(response).to render_template("feeds/version_bits")
        expect(response.body).to include("Version bits")
        expect(response.body).to include("#{ ENV['VERSION_BITS_THRESHOLD'] } times")
      end

      it "should contain version bit" do
        get :version_bits, format: :rss
        expect(response.body).to include("#{version_bit.bit}")
      end
    end

    describe "GET stale_candidates feed" do
      before do
        @block1 = create(:block, coin: :btc, height: 500000)
        @stale_candidate = create(:stale_candidate, coin: :btc, height: 500000)
      end

      it "should be rendered" do
        get :stale_candidates, params: {coin: "btc"}, format: :rss
        expect(response).to render_template("feeds/stale_candidates")
        expect(response.body).to include("BTC stale block candidates")
      end

      it "should contain block hashes" do
        get :stale_candidates, params: {coin: "btc"}, format: :rss
        expect(response.body).to include(@block1.block_hash)
      end

      it "should be paginated" do
        get :stale_candidates, params: {coin: "btc", page: 2}, format: :rss
        expect(response.body).not_to include(@block1.block_hash)
      end
    end

    describe "GET lightning penalty feed" do
      let!(:lightning_transaction) { create(:penalty_transaction_public) }

      it "should be rendered" do
        get :ln_penalties, params: {coin: "btc"}, format: :rss
        expect(response).to render_template("feeds/ln_penalties")
        expect(response.body).to include("Lightning penalty transactions")
      end

      it "should contain penalty transactions" do
        get :ln_penalties, params: {coin: "btc"}, format: :rss
        expect(response.body).to include("c64564a132778ba71ffb6188f7b92dac7c5d22afabeaec31f130bbd201ebb1b6")
      end
    end

    describe "GET lightning sweep feed" do
      let!(:lightning_transaction) { create(:sweep_transaction_public) }

      it "should be rendered" do
        get :ln_sweeps, params: {coin: "btc"}, format: :rss
        expect(response).to render_template("feeds/ln_sweeps")
        expect(response.body).to include("Lightning sweep transactions")
      end

      it "should contain sweep transactions" do
        get :ln_sweeps, params: {coin: "btc"}, format: :rss
        expect(response.body).to include("a08e6620d21b8f451c63dfe8d0164f0ba1b2dc781ea163c7990634747b57282c")
      end
    end

    describe "GET lightning potential close feed" do
      let!(:lightning_transaction) { create(:maybe_uncoop_transaction) }

      it "should be rendered" do
        get :ln_uncoops, params: {coin: "btc"}, format: :rss
        expect(response).to render_template("feeds/ln_uncoops")
        expect(response.body).to include("uncooperative")
      end

      it "should contain potential uncooperative close transactions" do
        get :ln_uncoops, params: {coin: "btc"}, format: :rss
        expect(response.body).to include("5cc28d4a2deeb4e6079c649645e36a1e2813605f65fdea242afb70d7677c1e03")
      end
    end

  end
end
