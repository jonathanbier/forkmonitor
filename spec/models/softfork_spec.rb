# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Softfork do
  let(:node) { create(:node_with_block, version: 200_000) }

  describe 'process' do
    it 'does nothing if no forks are active' do
      blockchaininfo = {
        'chain' => 'main',
        'softforks' => {}
      }
      described_class.process(node, blockchaininfo)
      expect(described_class.count).to eq(0)
    end

    it 'adds an active bip9 softfork' do
      blockchaininfo = {
        'chain' => 'main',
        'softforks' => {
          'segwit' => {
            'type' => 'bip9',
            'bip9' => {
              'status' => 'active',
              'bit' => 1,
              'height' => 481_824
            }
          }
        }
      }
      described_class.process(node, blockchaininfo)
      expect(described_class.count).to eq(1)

      # If a softfork status is not "defined" when a node is first polled, consider
      # it a status change and send notification:
      expect(described_class.first.notified_at).to be_nil

      # And not more than once
      described_class.process(node, blockchaininfo)
      expect(described_class.count).to eq(1)
    end

    it 'handles a status update' do
      blockchaininfo = {
        'chain' => 'main',
        'softforks' => {
          'segwit' => {
            'type' => 'bip9',
            'bip9' => {
              'status' => 'defined',
              'bit' => 1,
              'height' => 470_000
            }
          }
        }
      }
      described_class.process(node, blockchaininfo)
      expect(described_class.count).to eq(1)
      expect(described_class.first.status).to eq('defined')
      # Don't notify when status is defined
      expect(described_class.first.notified_at).not_to be_nil

      blockchaininfo = {
        'chain' => 'main',
        'softforks' => {
          'segwit' => {
            'type' => 'bip9',
            'bip9' => {
              'status' => 'active',
              'bit' => 1,
              'height' => 481_824
            }
          }
        }
      }
      described_class.process(node, blockchaininfo)
      expect(described_class.count).to eq(1)
      expect(described_class.first.status).to eq('active')
      # Status change should trigger notification
      expect(described_class.first.notified_at).to be_nil
    end

    it 'parses pre 0.19 format' do
      node.version = 180_100
      blockchaininfo = {
        'chain' => 'main',
        'bip9_softforks' => {
          'segwit' => {
            'status' => 'active',
            'height' => 481_824
          }
        }
      }
      described_class.process(node, blockchaininfo)
      expect(described_class.count).to eq(1)

      # And not more than once
      described_class.process(node, blockchaininfo)
      expect(described_class.count).to eq(1)
    end

    it 'ignores burried softforks' do
      blockchaininfo = {
        'chain' => 'main',
        'softforks' => {
          'bip66' => {
            'type' => 'buried',
            'active' => true,
            'height' => 363_725
          }
        }
      }
      described_class.process(node, blockchaininfo)
      expect(described_class.count).to eq(0)
    end
  end
end
