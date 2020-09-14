class StaleCandidate < ApplicationRecord
  PER_PAGE = Rails.env.production? ? 100 : 2
  DOUBLE_SPEND_RANGE = 10

  enum coin: [:btc, :bch, :bsv, :tbtc]

  after_commit :expire_cache

  scope :feed, -> {
    # RSS feed switched to new GUID. Drop old items to prevent spurious notifications.
    where(
      "created_at >= ?", DateTime.civil_from_format(:local, 2020, 7, 15)
    )
  }

  def as_json(options = nil)
    children = self.children # avoid repeating this operation
    super({ only: [:coin, :height] }).merge({
      children: children,
      double_spend_candidates: double_spend_candidates(children)
    })
  end

  def json_cached
    Rails.cache.fetch("StaleCandidate(#{ self.id }).json") {
      self.to_json
    }
  end

  def children
    Block.where(coin: coin, height: height).collect{ | child |
      chain = Block.where("height <= ?", height + 100).join_recursive {
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

  def double_spend_candidates(children)
    return nil if children.length < 2
    # TODO: handle more than 2 branches:
    return nil if children.length > 2
    # If branches are of different length, potential double spends are transactions
    # in the shortest chain that are missing in the longest chain.
    (shortest, longest) = children.sort_by {|c| c[:length] }
    shortest_tx_ids = shortest[:root].block_and_descendant_transaction_ids(DOUBLE_SPEND_RANGE)
    longest_tx_ids = longest[:root].block_and_descendant_transaction_ids(DOUBLE_SPEND_RANGE)
    if shortest[:length] < longest[:length]
      tx_ids = shortest_tx_ids - longest_tx_ids
    else
      # If both branches are the same length, consider doublespends on either side:
      tx_ids = (shortest_tx_ids - longest_tx_ids) | (longest_tx_ids - shortest_tx_ids)
    end

    # TODO: take RBF into account (fee bump is not a double spend)

    # Return transaction details
    Transaction.where("tx_id in (?)", tx_ids)
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

  # Iterate over descendant blocks to add their transactions
  def process!
    Rails.logger.info "Processing stale candidates at height #{ self.height }..."
    Block.where(coin: self.coin, height: self.height).each do |candidate_block|
      candidate_block.fetch_transactions!
      Rails.logger.debug "Fetch descendants"
      candidate_block.descendants.where("height <= ?", self.height + 10).each do |block|
        block.fetch_transactions!
      end
    end
  end

  def self.check!(coin)
    # Look for potential stale blocks, i.e. more than one block at the same height
    tip_height = Block.where(coin: coin).maximum(:height)
    return if tip_height.nil?
    block_window = Rails.env.test? ? 2 : 100
    Block.select(:height).where(coin: coin).where("height > ?", tip_height - block_window).group(:height).having('count(height) > 1').order(height: :asc).limit(1).each do |block|
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
      block.fetch_transactions!
    end
    return s
  end

  def self.process!(coin)
    # Only process the most recent stale candidate
    StaleCandidate.where(coin: coin).order(height: :desc).limit(1).each do |c|
      c.process!
    end
  end

  def notify!
    if self.notified_at.nil?
      User.all.each do |user|
        unless self.tbtc? # skip email notification for testnet
          UserMailer.with(user: user, stale_candidate: self).stale_candidate_email.deliver
        end
      end
      self.update notified_at: Time.now
      unless self.tbtc? # skip push notification for testnet
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
      min_height = Block.where(coin: coin).maximum(:height) - 1000
      where(coin: coin).where("height > ?", min_height).order(height: :desc).limit(1).to_json
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
