class StaleCandidate < ApplicationRecord
  PER_PAGE = Rails.env.production? ? 100 : 2

  enum coin: [:btc, :bch, :bsv, :tbtc]

  after_commit :expire_cache

  private

  def self.last_updated_cached(coin)
      Rails.cache.fetch("StaleCandidate.last_updated(#{ coin })") {
        where(coin: coin).order(updated_at: :desc).first
      }
  end

  def self.page_cached(coin, page)
      Rails.cache.fetch("StaleCandidate.for_coin(#{ coin },#{page})") {
        where(coin: coin).order(created_at: :desc).offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
      }
  end

  def expire_cache
    Rails.cache.delete("StaleCandidate.last_updated(#{self.coin})")
    for page in 1...(StaleCandidate.count / PER_PAGE + 1) do
      Rails.cache.delete("StaleCandidate.for_coin(#{ coin },#{page})")
    end
    Rails.cache.delete("StaleCandidate.count(#{self.coin})")
  end
end
