# frozen_string_literal: true

class Pool < ApplicationRecord
  class << self
    def fetch!
      res = JSON.parse(open('vendor/known-mining-pools/pools.json').read)
      res['coinbase_tags'].each do |tag, info|
        Pool.create_with(name: info['name'], url: info['link']).find_or_create_by(tag: tag)
      end
    end
  end
end
