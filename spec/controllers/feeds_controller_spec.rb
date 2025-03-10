# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedsController do
  describe 'RSS feed' do
    render_views

    describe 'GET inflated_block feed' do
      let!(:inflated_block) { create(:inflated_block) }

      it 'is rendered' do
        get :inflated_blocks, format: :rss
        expect(response).to render_template('feeds/inflated_blocks')
        expect(response.body).to include('Inflated blocks')
      end

      it 'contains inflated blocks' do
        get :inflated_blocks, format: :rss
        expect(response.body).to include("#{inflated_block.actual_inflation - inflated_block.max_inflation} BTC")
      end
    end

    describe 'GET blocks_invalid feed' do
      let!(:node) { create(:node) }
      let!(:block) { create(:block) }

      before do
        block.update marked_invalid_by: [node.id]
      end

      it 'is rendered' do
        get :blocks_invalid, format: :rss
        expect(response).to render_template('feeds/blocks_invalid')
        expect(response.body).to include('Invalid blocks')
      end

      it 'contains invalid blocks' do
        get :blocks_invalid, format: :rss
        expect(response.body).to include(node.name_with_version)
      end
    end

    describe 'GET invalid_block feed' do
      let!(:node) { create(:node) }
      let!(:invalid_block) { create(:invalid_block) }

      before do
        invalid_block.block.update marked_valid_by: [node.id]
      end

      it 'is rendered' do
        get :invalid_blocks, format: :rss
        expect(response).to render_template('feeds/invalid_blocks')
        expect(response.body).to include('Invalid blocks')
      end

      it 'contains invalid blocks' do
        get :invalid_blocks, format: :rss
        expect(response.body).to include(invalid_block.node.name_with_version)
      end
    end

    describe 'GET lagging_nodes feed' do
      let!(:lagging_node) { create(:lag) }

      it 'is rendered' do
        get :lagging_nodes, format: :rss
        expect(response).to render_template('feeds/lagging_nodes')
        expect(response.body).to include('behind')
      end

      it 'contains a lagging node' do
        get :lagging_nodes, format: :rss
        expect(response.body).to include(lagging_node.node_a.name_with_version)
      end
    end

    describe 'GET nodes/unreachable feed' do
      let!(:node) { create(:node, unreachable_since: 1.hour.ago) }

      it 'is rendered' do
        get :unreachable_nodes, format: :rss
        expect(response).to render_template('feeds/unreachable_nodes')
        expect(response.body).to include('unreachable')
      end

      it 'contains an unreachable node' do
        get :unreachable_nodes, format: :rss
        expect(response.body).to include(node.name_with_version)
      end
    end

    describe 'GET version_bits feed' do
      let!(:version_bit) { create(:version_bit) }

      it 'is rendered' do
        get :version_bits, format: :rss
        expect(response).to render_template('feeds/version_bits')
        expect(response.body).to include('Version bits')
        expect(response.body).to include("#{ENV.fetch('VERSION_BITS_THRESHOLD', nil)} times")
      end

      it 'contains version bit' do
        get :version_bits, format: :rss
        expect(response.body).to include(version_bit.bit.to_s)
      end
    end

    describe 'GET stale_candidates feed' do
      let!(:block_1) { create(:block, height: 500_000) }

      before do
        create(:stale_candidate, height: 500_000)
      end

      it 'is rendered' do
        get :stale_candidates, format: :rss
        expect(response).to render_template('feeds/stale_candidates')
        expect(response.body).to include('Stale block candidates')
      end

      it 'contains block hashes' do
        get :stale_candidates, format: :rss
        expect(response.body).to include(block_1.block_hash)
      end

      it 'is paginated' do
        get :stale_candidates, params: { page: 2 }, format: :rss
        expect(response.body).not_to include(block_1.block_hash)
      end

      it 'rejects negative page numbers' do
        get :stale_candidates, params: { page: -2 }, format: :rss
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
