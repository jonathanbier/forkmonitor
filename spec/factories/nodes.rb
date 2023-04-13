# frozen_string_literal: true

FactoryBot.define do
  factory :node do
    coin { :btc }
    name { 'Bitcoin Core' }
    version { 230_000 }
    client_type { :core }
    enabled { true }
  end

  factory :node_with_block, parent: :node do
    block
  end

  factory :node_with_chaintip, parent: :node_with_block do |_node|
    chaintips { build_list(:chaintip, 1, block: block, status: 'active') }
  end

  factory :node_with_mirror, parent: :node do
    mirror_rpchost { '127.0.0.1' }
    mirror_rpcport { 8336 }
  end

  factory :node_python, parent: :node do
    python { true }
  end

  factory :node_python_with_mirror, parent: :node_python do
    python { true }
    mirror_rpchost { '127.0.0.1' } # ignored
    mirror_rpcport { 8336 } # ignored
  end
end
