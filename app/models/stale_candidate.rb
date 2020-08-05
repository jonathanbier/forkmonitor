class StaleCandidate < ApplicationRecord
  PER_PAGE = Rails.env.production? ? 100 : 2

  enum coin: [:btc, :bch, :bsv, :tbtc]

  after_commit :expire_cache

  scope :feed, -> {
    # RSS feed switched to new GUID. Drop old items to prevent spurious notifications.
    where(
      "created_at >= ?", DateTime.civil_from_format(:local, 2020, 7, 15)
    )
  }

  def as_json(options = nil)
    super({ only: [:coin, :height] }).merge({
      children: children
    })
  end

  def json_cached
    Rails.cache.fetch("StaleCandidate(#{ self.id }).json") {
      self.to_json
    }
  end

  def children
    Block.where(coin: coin, height: height).collect{ | child |
      chain = Block.join_recursive {
        start_with(block_hash: child.block_hash).
        connect_by(id: :parent_id).
        order_siblings(:work)
      }
      {
        root: child,
        tip: chain[-1],
        length: chain.count
      }
    }
  end

  def expire_cache
    Rails.cache.delete("StaleCandidate(#{ self.id }).json")
    Rails.cache.delete("StaleCandidate.index.for_coin(#{ self.coin }).json")
    Rails.cache.delete("StaleCandidate.last_updated(#{self.coin})")
    for page in 1...(StaleCandidate.feed.count / PER_PAGE + 1) do
      Rails.cache.delete("StaleCandidate.feed.for_coin(#{ coin },#{page})")
    end
    Rails.cache.delete("StaleCandidate.feed.count(#{self.coin})")
  end

  private

  def self.index_json_cached(coin)
    Rails.cache.fetch("StaleCandidate.index.for_coin(#{ coin }).json") {
      where(coin: coin).order(height: :desc).limit(1).to_json
    }
  end

  def self.last_updated_cached(coin)
      Rails.cache.fetch("StaleCandidate.last_updated(#{ coin })") {
        where(coin: coin).order(updated_at: :desc).first
      }
  end

  def self.page_cached(coin, page)
      Rails.cache.fetch("StaleCandidate.feed.for_coin(#{ coin },#{page})") {
        feed.where(coin: coin).order(created_at: :desc).offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
      }
  end

end
