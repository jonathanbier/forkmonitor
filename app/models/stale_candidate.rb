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

  def self.check!(coin)
    # Look for potential stale blocks, i.e. more than one block at the same height
    tip_height = Block.where(coin: coin).maximum(:height)
    return if tip_height.nil?
    block_window = Rails.env.test? ? 2 : 100
    Block.select(:height).where(coin: coin).where("height > ?", tip_height - block_window).group(:height).having('count(height) > 1').each do |block|
      # If there was an invalid block, assume there's fork:
      # TODO: check the chaintips; perhaps there's both a fork and a stale block on one side
      #       until then, we assume a forked node is deleted and the alert is dismissed
      next if InvalidBlock.joins(:block).where(dismissed_at: nil).where("blocks.coin = ?", Block.coins[coin]).count > 0
      stale_candidate = find_or_generate(coin, block.height)
      stale_candidate.notify!
    end
  end

  def self.find_or_generate(coin, height)
    throw "Expected at least two #{ coin } blocks at height #{ height }" unless Block.where(coin: coin, height: height).count > 1
    s = StaleCandidate.find_or_create_by(coin: coin, height: height)
    # Fetch transactions for all blocks at this height
    Block.where(coin: coin, height: height).each do |block|
      if block.transactions.count == 0
        # TODO: if node doesn't have getblock equivalent (e.g. libbitcoin), try other nodes
        block_info = block.first_seen_by.getblock(block.block_hash, 1)
        coinbase = block_info["tx"].first
        block.transactions.create(is_coinbase: true, tx_id: coinbase)
        block_info["tx"][1..-1].each do |tx_id|
          block.transactions.create(is_coinbase: false, tx_id: tx_id)
        end
      end
    end
    return s
  end

  def self.process!(coin)
  end

  def notify!
    if self.notified_at.nil?
      User.all.each do |user|
        if ![:tbtc].include?(self.coin) # skip email notification for testnet
          UserMailer.with(user: user, stale_candidate: self).stale_candidate_email.deliver
        end
      end
      self.update notified_at: Time.now
      if ![:tbtc].include?(self.coin) # skip push notification for testnet
        Subscription.blast("stale-candidate-#{ self.id }",
                           "#{ self.coin.upcase } stale candidate",
                           "At height #{ self.height }"
        )
      end
    end
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
