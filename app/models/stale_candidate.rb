class StaleCandidate < ApplicationRecord
  PER_PAGE = Rails.env.production? ? 100 : 2
  DOUBLE_SPEND_RANGE = Rails.env.production? ? 30 : 10
  STALE_BLOCK_WINDOW = Rails.env.test? ? 5 : 100

  enum coin: [:btc, :bch, :bsv, :tbtc]

  has_many :children, class_name: "StaleCandidateChild", dependent: :destroy

  scope :feed, -> {
    # RSS feed switched to new GUID. Drop old items to prevent spurious notifications.
    where(
      "created_at >= ?", DateTime.civil_from_format(:local, 2020, 7, 15)
    )
  }

  def as_json(options = nil)
    if options[:short]
      super({ only: [:coin, :height, :n_children] })
    else
      super({ only: [:coin, :height, :n_children] }).merge({
        children: children.sort_by {|c| c.root.timestamp || c.root.created_at.to_i },
        headers_only: children.any? { |c| c.root.headers_only }
      })
    end
  end

  def json_cached(fetch=true)
    cache_key = "StaleCandidate(#{ self.id }).json"
    return nil if !fetch && !Rails.cache.exist?(cache_key)
    Rails.cache.fetch(cache_key) {
      self.to_json
    }
  end

  # Exclude double_spent_in_one_branch
  def confirmed_in_one_branch_txs
    Transaction.where("tx_id in (?)", confirmed_in_one_branch - double_spent_in_one_branch).select("tx_id, max(amount) as amount").group(:tx_id).order("amount DESC")
  end

  def double_spent_in_one_branch_txs
    Transaction.where("tx_id in (?)", double_spent_in_one_branch).select("tx_id, max(amount) as amount").group(:tx_id).order("amount DESC")
  end

  def double_spend_info
    {
      n_children: self.children.count,
      children: self.children,
      confirmed_in_one_branch: self.confirmed_in_one_branch_txs,
      confirmed_in_one_branch_total: (self.confirmed_in_one_branch_total || 0) - (self.double_spent_in_one_branch_total || 0),
      double_spent_in_one_branch: self.double_spent_in_one_branch_txs,
      double_spent_in_one_branch_total: self.double_spent_in_one_branch_total,
      headers_only: children.any? { |child| child.root.headers_only }
    }.to_json
  end

  def double_spend_info_cached(fetch=true)
    cache_key = "StaleCandidate(#{ self.id })/double_spend_info.json"
    return nil if !fetch && !Rails.cache.exist?(cache_key)
    Rails.cache.fetch(cache_key) {
      self.double_spend_info
    }
  end

  def get_confirmed_in_one_branch
    return nil if self.children.length < 2
    # TODO: handle more than 2 branches:
    return nil if self.children.length > 2
    # If branches are of different length, potential double spends are transactions
    # in the shortest chain that are missing in the longest chain.
    (shortest, longest) = self.children.sort_by {|c| c.length }
    return nil if shortest.root.headers_only || longest.root.headers_only
    shortest_tx_ids = shortest.root.block_and_descendant_transaction_ids(DOUBLE_SPEND_RANGE)
    longest_tx_ids = longest.root.block_and_descendant_transaction_ids(DOUBLE_SPEND_RANGE)
    if shortest.length < longest.length
      # Transactions that were created on the shortest side, but not on the longest:
      tx_ids = shortest_tx_ids - longest_tx_ids
    else
      # If both branches are the same length, consider unique transactions on either side:
      tx_ids = (shortest_tx_ids - longest_tx_ids) | (longest_tx_ids - shortest_tx_ids)
    end

    # TODO: take RBF into account (fee bump is not a double spend)

    # Return transaction details (database id is omitted)
    return tx_ids
  end

  def get_double_spent_inputs
    return nil if self.children.length < 2
    # TODO: handle more than 2 branches:
    return nil if self.children.length > 2
    # If branches are of different length, double spends are inputs spent
    # in the shortest chain that also spent by a different transaction in the longest chain
    (shortest, longest) = self.children.sort_by {|c| c.length }
    return nil if shortest.root.headers_only || longest.root.headers_only
    shortest_txs = shortest.root.block_and_descendant_transactions(DOUBLE_SPEND_RANGE)
    longest_txs = longest.root.block_and_descendant_transactions(DOUBLE_SPEND_RANGE)
    return nil if shortest_txs.nil? || longest_txs.nil?

    longest_spent_coins_with_tx = longest_txs.collect { | tx |
      tx.spent_coins_map
    }.inject(&:merge)
    shortest_spent_coins_with_tx = shortest_txs.collect { | tx |
      tx.spent_coins_map
    }.inject(&:merge)
    return nil if longest_spent_coins_with_tx.nil? || shortest_spent_coins_with_tx.nil?
    # Filter coins that are spent with a different tx in the longest chain
    txs = shortest_spent_coins_with_tx.filter { |txout, tx|
      longest_spent_coins_with_tx.key?(txout) && tx.tx_id != longest_spent_coins_with_tx[txout].tx_id
      # TODO: take RBF into account (fee bump is not a double spend)
    }.collect{|txout, tx| tx}.uniq
  end

  def expire_cache
    self.children.destroy_all
    self.update confirmed_in_one_branch: [], confirmed_in_one_branch_total: nil, double_spent_in_one_branch: [], double_spent_in_one_branch_total: nil
    Rails.cache.delete("StaleCandidate(#{ self.id }).json")
    Rails.cache.delete("StaleCandidate(#{ self.id })/double_spend_info.json")
    Rails.cache.delete("StaleCandidate.index.for_coin(#{ self.coin }).json")
    Rails.cache.delete("StaleCandidate.last_updated(#{self.coin})")
    for page in 1...(StaleCandidate.feed.count / PER_PAGE + 1) do
      Rails.cache.delete("StaleCandidate.feed.for_coin(#{ coin },#{page})")
    end
    Rails.cache.delete("StaleCandidate.feed.count(#{self.coin})")
  end

  # Iterate over descendant blocks to add their transactions
  def process!
    Block.where(coin: self.coin, height: self.height).each do |candidate_block|
      candidate_block.fetch_transactions!
      candidate_block.descendants.where("height <= ?", self.height + DOUBLE_SPEND_RANGE).each do |block|
        block.fetch_transactions!
      end
    end
  end

  def self.check!(coin)
    # Look for potential stale blocks, i.e. more than one block at the same height
    tip_height = Block.where(coin: coin).maximum(:height)
    return if tip_height.nil?
    Block.select(:height).where(coin: coin).where("height > ?", tip_height - STALE_BLOCK_WINDOW).group(:height).having('count(height) > 1').order(height: :asc).each do |block|
      # If there are is more than 1 block at the previous height, assume we already have a stale block entry:
      next if Block.where(coin: coin, height: block.height - 1).count > 1
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
    s = StaleCandidate.create_with(n_children: Block.where(coin: coin, height: height).count).find_or_create_by(coin: coin, height: height)
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

  def prime_cache
    return false if Rails.cache.exist?("StaleCandidate(#{ self.id }).json")
    Rails.logger.info "Prime cache for #{ coin.to_s.upcase } stale candidate #{ self.height }..."
    # This check prevents wasting time on each deploy reprocessing old stale
    # blocks. For recent stale blocks, the children are cleared in expire_cache.
    # In order to repopulate this data for older blocks, clear the StaleCandidateChild table.
    if self.children.count == 0
      Block.where(coin: coin, height: self.height).each do |root|
        chain = Block.where("height <= ?", height + 100).join_recursive {
          start_with(block_hash: root.block_hash).
          connect_by(id: :parent_id).
          order_siblings(:work)
        }
        self.children.create(
          root: root,
          tip: chain[-1], # TODO: this and the next line cause two very slow queries
          length: chain.count
        )
      end
      # Make this cache available early:
      self.json_cached
      Rails.logger.info "Prime confirmed in one branch cache for #{ coin.to_s.upcase } stale candidate #{ self.height }..."
      self.update n_children: self.children.count
      self.update confirmed_in_one_branch: self.get_confirmed_in_one_branch
      self.update confirmed_in_one_branch_total: (self.confirmed_in_one_branch.nil? || self.confirmed_in_one_branch.count == 0) ? 0 : Transaction.where("tx_id in (?)", self.confirmed_in_one_branch).select("tx_id, max(amount) as amount").group(:tx_id).collect{|tx| tx.amount}.inject(:+)
      Rails.logger.info "Prime doublespend cache for #{ coin.to_s.upcase } stale candidate #{ self.height }..."
      txs = self.get_double_spent_inputs
      self.update double_spent_in_one_branch: txs.nil? ? nil : txs.collect{|tx| tx.tx_id}
      self.update double_spent_in_one_branch_total: txs.nil? ? nil : txs.collect{|tx| tx.amount}.inject(:+)
    end
    self.json_cached
    self.double_spend_info_cached
    true
  end

  def self.prime_cache(coin)
    raise InvalidCoinError unless Node::SUPPORTED_COINS.include?(coin)
    unless Rails.cache.exist?("StaleCandidate.index.for_coin(#{ coin }).json")
      Rails.logger.info "Prime stale candidate index for #{ coin.to_s.upcase }..."
      StaleCandidate.index_json_cached(coin)
    end

    min_height = Block.where(coin: coin).maximum(:height) - 20000
    StaleCandidate.where(coin: coin).where("height > ?", min_height).order(height: :desc).each do |s|
      # Prime cache one at a time
      return if s.prime_cache
    end
  end

  private

  def self.index_json_cached(coin)
    raise InvalidCoinError unless Node::SUPPORTED_COINS.include?(coin)
    Rails.cache.fetch("StaleCandidate.index.for_coin(#{ coin }).json") {
      min_height = Block.where(coin: coin).maximum(:height) - 1000
      where(coin: coin).where("height > ?", min_height).order(height: :desc).limit(1).to_json({short: true})
    }
  end

  def self.last_updated_cached(coin)
    raise InvalidCoinError unless Node::SUPPORTED_COINS.include?(coin)
    Rails.cache.fetch("StaleCandidate.last_updated(#{ coin })") {
      where(coin: coin).order(updated_at: :desc).first
    }
  end

  def self.page_cached(coin, page)
    raise InvalidCoinError unless Node::SUPPORTED_COINS.include?(coin)
    Rails.cache.fetch("StaleCandidate.feed.for_coin(#{ coin },#{page})") {
      feed.where(coin: coin).order(created_at: :desc).offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    }
  end

end
