class StaleCandidate < ApplicationRecord
  enum coin: [:btc, :bch, :bsv, :tbtc]

  after_save    :expire_cache
  after_destroy :expire_cache

  private

  def self.last_updated_cached(coin)
      Rails.cache.fetch("StaleCandidate.last_updated('#{ coin }')") {
        where(coin: coin).order(updated_at: :desc).first
      }
  end

  def self.page_cached(coin, per_page, page)
      Rails.cache.fetch("StaleCandidate.for_coin('#{ coin }',#{per_page},#{page})") {
        where(coin: coin).order(created_at: :desc).offset((page - 1) * per_page).limit(per_page).to_a
      }
  end

  def expire_cache
    Rails.cache.delete_matched("StaleCandidate*")
  end
end
