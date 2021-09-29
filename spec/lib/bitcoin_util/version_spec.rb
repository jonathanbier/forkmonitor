# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BitcoinUtil::Version do
  describe 'name_with_version' do
    it 'combines node name with version' do
      expect(described_class.name_with_version('Bitcoin Core', 170_001, '', :core)).to eq('Bitcoin Core 0.17.0.1')
    end

    it 'handles clients that self identify with four digits' do
      expect(described_class.name_with_version('Bitcoin Unlimited', 1_060_000, '', :bu)).to eq('Bitcoin Unlimited 1.6.0.0')
    end

    it 'drops the 4th digit if zero' do
      expect(described_class.name_with_version('Bitcoin Core', 170_000, '', :core)).to eq('Bitcoin Core 0.17.0')
    end

    it 'handles 22.0.1 version' do
      expect(described_class.name_with_version('Bitcoin Core', 220_001, '', :core)).to eq('Bitcoin Core 22.0.1')
    end

    it 'drops the 3rd and 4th digit if zero' do
      expect(described_class.name_with_version('Bitcoin Core', 220_000, '', :core)).to eq('Bitcoin Core 22.0')
    end

    it 'handles 22.1 version' do
      expect(described_class.name_with_version('Bitcoin Core', 220_100, '', :core)).to eq('Bitcoin Core 22.1')
    end

    it 'appends version_extra' do
      expect(described_class.name_with_version('Bitcoin Core', 170_000, 'rc1', :core)).to eq('Bitcoin Core 0.17.0rc1')
    end

    it 'hides version if absent' do
      expect(described_class.name_with_version('Libbitcoin', nil, '', :libbitcoin)).to eq('Libbitcoin')
    end

    it 'adds version_extra if set while version is absent' do
      expect(described_class.name_with_version('Libbitcoin', nil, '3.6.0', :libbitcoin)).to eq('Libbitcoin 3.6.0')
    end
  end

  describe 'parse' do
    it 'parses v0.21.0' do
      expect(described_class.parse('0.21.0', :core)).to eq(210_000)
    end

    it 'parses v22.0' do
      expect(described_class.parse('22.0', :core)).to eq(220_000)
    end

    it 'parses v22.0.1' do
      expect(described_class.parse('22.0.1', :core)).to eq(220_001)
    end
  end
end
