# frozen_string_literal: true

require 'open-uri'

class Pool < ApplicationRecord
  class << self
    def fetch!
      res = JSON.load(URI.open('https://raw.githubusercontent.com/0xB10C/known-mining-pools/master/pools.json'))
      res['coinbase_tags'].each do |tag, info|
        Pool.create_with(name: info['name'], url: info['link']).find_or_create_by(tag: tag)
      end
    end
  end
end
