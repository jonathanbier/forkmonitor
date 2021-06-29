# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BitcoinUtil::Version do
  describe 'name_with_version' do
    it 'combines node name with version' do
      expect(described_class.name_with_version('Bitcoin Core', 170_001, '', false)).to eq('Bitcoin Core 0.17.0.1')
    end

    it 'handles 1.0 version' do
      expect(described_class.name_with_version('Bitcoin Core', 1_000_000, '', false)).to eq('Bitcoin Core 1.0.0')
    end

    it 'handles clients that self identify with four digits' do
      expect(described_class.name_with_version('Bitcoin Unlimited', 1_060_000, '', true)).to eq('Bitcoin Unlimited 1.6.0.0')
    end

    it 'drops the 4th digit if zero' do
      expect(described_class.name_with_version('Bitcoin Core', 170_000, '', false)).to eq('Bitcoin Core 0.17.0')
    end

    it 'appends version_extra' do
      expect(described_class.name_with_version('Bitcoin Core', 170_000, 'rc1', false)).to eq('Bitcoin Core 0.17.0rc1')
    end

    it 'hides version if absent' do
      expect(described_class.name_with_version('Libbitcoin', nil, '', false)).to eq('Libbitcoin')
    end

    it 'adds version_extra if set while version is absent' do
      expect(described_class.name_with_version('Libbitcoin', nil, '3.6.0', false)).to eq('Libbitcoin 3.6.0')
    end
  end
end
