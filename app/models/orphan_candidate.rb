class OrphanCandidate < ApplicationRecord
  enum coin: [:btc, :bch, :bsv]
end
