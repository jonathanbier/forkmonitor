require 'rails_helper'

RSpec.describe FeedsController, type: :controller do
  describe "RSS feed" do
    render_views

    describe "GET invalid_block feed" do
      let!(:invalid_block) { create(:invalid_block) }

      it "should be rendered" do
        get :invalid_blocks, format: :rss
        expect(response).to render_template("feeds/invalid_blocks")
        expect(response.body).to include("Invalid blocks")
      end

      it "should contain invalid blocks" do
        get :invalid_blocks, format: :rss
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

  end
end
