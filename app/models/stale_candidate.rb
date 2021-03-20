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

  def json_cached
    cache_key = "StaleCandidate(#{ self.id }).json"
    return nil if self.height_processed.nil?
    Rails.cache.fetch(cache_key) {
      self.to_json
    }
  end

  # Exclude double_spent_in_one_branch
  def confirmed_in_one_branch_txs
    Transaction.where("tx_id in (?)", confirmed_in_one_branch - double_spent_in_one_branch).select("tx_id, max(amount) as amount").group(:tx_id).order("amount DESC")
  end

  def double_spent_in_one_branch_txs
    Transaction.where("tx_id in (?)", double_spent_in_one_branch - rbf).select("tx_id, max(amount) as amount").group(:tx_id).order("amount DESC")
  end

  def double_spent_by_txs
    Transaction.where("tx_id in (?)", double_spent_by - rbf_by).select("tx_id, max(amount) as amount").group(:tx_id).order("amount DESC")
  end

  def rbf_txs
    Transaction.where("tx_id in (?)", rbf).select("tx_id, max(amount) as amount").group(:tx_id).order("amount DESC")
  end

  def rbf_by_txs
    Transaction.where("tx_id in (?)", rbf_by).select("tx_id, max(amount) as amount").group(:tx_id).order("amount DESC")
  end

  def double_spend_info
    {
      height_processed: self.height_processed,
      n_children: self.children.count,
      children: self.children,
      missing_transactions: self.missing_transactions,
      confirmed_in_one_branch: self.confirmed_in_one_branch_txs,
      confirmed_in_one_branch_total: (self.confirmed_in_one_branch_total || 0) - (self.double_spent_in_one_branch_total || 0),
      double_spent_in_one_branch: self.double_spent_in_one_branch_txs,
      double_spent_by: self.double_spent_by_txs,
      double_spent_in_one_branch_total: (self.double_spent_in_one_branch_total || 0) - (self.rbf_total || 0),
      rbf: self.rbf_txs,
      rbf_by: self.rbf_by_txs,
      rbf_total: self.rbf_total,
      headers_only: children.any? { |child| child.root.headers_only }
    }.to_json
  end

  def double_spend_info_cached
    cache_key = "StaleCandidate(#{ self.id })/double_spend_info.json"
    return nil if self.height_processed.nil?
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
    # Ensure we have transactions for all child blocks
    return nil if ([shortest.root] + shortest.root.descendants(DOUBLE_SPEND_RANGE)).any? { |block| block.transactions.count == 0 }
    return nil if ([longest.root] + longest.root.descendants(DOUBLE_SPEND_RANGE)).any? { |block| block.transactions.count == 0 }
    shortest_tx_ids = shortest.root.block_and_descendant_transaction_ids(DOUBLE_SPEND_RANGE)
    longest_tx_ids = longest.root.block_and_descendant_transaction_ids(DOUBLE_SPEND_RANGE)
    if shortest.length < longest.length
      # Transactions that were created on the shortest side, but not on the longest:
      tx_ids = shortest_tx_ids - longest_tx_ids
    else
      # If both branches are the same length, consider unique transactions on either side:
      tx_ids = (shortest_tx_ids - longest_tx_ids) | (longest_tx_ids - shortest_tx_ids)
    end

    # Return transaction details (database id is omitted)
    return tx_ids
  end

  def get_spent_coins_with_tx
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

    return shortest_spent_coins_with_tx, longest_spent_coins_with_tx
  end

  def get_double_spent_inputs(spent_coins_with_tx)
    return nil if spent_coins_with_tx.nil?
    (shortest_spent_coins_with_tx, longest_spent_coins_with_tx) = spent_coins_with_tx

    # Filter coins that are spent with a different tx in the longest chain
    # unique is used because a transaction may doublespend multiple inputs
    txs = shortest_spent_coins_with_tx.filter { |txout, tx|
      longest_spent_coins_with_tx.key?(txout) && tx.tx_id != longest_spent_coins_with_tx[txout].tx_id
    }.collect{|txout, tx| [tx, longest_spent_coins_with_tx[txout]]}.uniq.transpose()
  end

  def get_rbf(spent_coins_with_tx)
    return nil if spent_coins_with_tx.nil?
    (shortest_spent_coins_with_tx, longest_spent_coins_with_tx) = spent_coins_with_tx

    # Filter coins that are spent with a different tx in the longest chain
    txs = shortest_spent_coins_with_tx.filter { |txout, tx|
      if !longest_spent_coins_with_tx.key?(txout)
        false
      elsif tx.tx_id == longest_spent_coins_with_tx[txout].tx_id
        false
      else
      # Check for fee bump (regardless of RBF flag):
      # Check that:
      # * none of the destinations changed
      # * none of the outputs varied by more than 0.0001 BTC
      # TODO:
      # * don't sort by output; it's brittle. Just check if the same output
      #   exists on the other side.
      # * be more flexible if a change output is added
        replacement = longest_spent_coins_with_tx[txout]
        # puts "#{ tx.tx_id } vs #{ replacement.tx_id }"
        sorted_outputs = tx.outputs.sort_by{ |output| output.pk_script }
        replacement_sorted_outputs = replacement.outputs.sort_by{ |output| output.pk_script }
        sorted_outputs.map.with_index { |output, i|
          # puts "#{i}: #{ output.pk_script == replacement_sorted_outputs[i].pk_script } #{ (output.value - replacement_sorted_outputs[i].value).abs }"
          output.pk_script != replacement_sorted_outputs[i].pk_script ||
          (output.value - replacement_sorted_outputs[i].value).abs > 10000
        }.none? { |res| res }
      end
    }.collect{|txout, tx| [tx, longest_spent_coins_with_tx[txout]]}.uniq.transpose()
  end

  def expire_cache
    Rails.cache.delete("StaleCandidate(#{ self.id }).json")
    Rails.cache.delete("StaleCandidate(#{ self.id })/double_spend_info.json")
    Rails.cache.delete("StaleCandidate.index.for_coin(#{ self.coin }).json")
    Rails.cache.delete("StaleCandidate.last_updated(#{self.coin})")
    for page in 1...(StaleCandidate.feed.count / PER_PAGE + 1) do
      Rails.cache.delete("StaleCandidate.feed.for_coin(#{ coin },#{page})")
    end
    Rails.cache.delete("StaleCandidate.feed.count(#{self.coin})")
  end

  def fetch_transactions_for_descendants!
    # Iterate over descendant blocks to add their transactions
    Block.where(coin: self.coin, height: self.height).each do |candidate_block|
      candidate_block.fetch_transactions!
      candidate_block.descendants.where("height <= ?", self.height + DOUBLE_SPEND_RANGE).each do |block|
        block.fetch_transactions!
      end
    end
  end

  def set_children!
    self.children.destroy_all # TODO: update records instead
    Block.where(coin: self.coin, height: self.height).each do |root|
      chain = Block.where("height <= ?", height + STALE_BLOCK_WINDOW).join_recursive {
        start_with(block_hash: root.block_hash).
        connect_by(id: :parent_id).
        order_siblings(:work)
      }
      tip = chain[-1]
      self.children.create(
        root: root,
        tip: tip,
        length: chain.count
      )
    end
  end

  def set_conflicting_tx_info!(tip_height)
    Rails.logger.info "Prime confirmed in one branch cache for #{ coin.to_s.upcase } stale candidate #{ self.height }..."
    missing_transactions = false
    self.update n_children: self.children.count
    confirmed_in_one_branch = self.get_confirmed_in_one_branch
    # TODO: check missing_transactions seperately and avoid expensive calls below
    if confirmed_in_one_branch.nil?
      confirmed_in_one_branch = []
      missing_transactions = true
    end
    confirmed_in_one_branch_total = confirmed_in_one_branch.count == 0 ? 0 : Transaction.where("tx_id in (?)", confirmed_in_one_branch).select("tx_id, max(amount) as amount").group(:tx_id).collect{|tx| tx.amount}.inject(:+)
    Rails.logger.info "Prime doublespend cache for #{ coin.to_s.upcase } stale candidate #{ self.height }..."
    spent_coins_with_tx = self.get_spent_coins_with_tx
    txs_short, txs_long = self.get_double_spent_inputs(spent_coins_with_tx)
    double_spent_in_one_branch = txs_short.nil? ? [] : txs_short.collect{|tx| tx.tx_id}
    double_spent_in_one_branch_total = txs_short.nil? ? 0 : txs_short.collect{|tx| tx.amount}.inject(:+)
    double_spent_by = txs_long.nil? ? [] : txs_long.collect{|tx| tx.tx_id}
    Rails.logger.info "Prime fee-bump cache for #{ coin.to_s.upcase } stale candidate #{ self.height }..."
    txs_short, txs_long = self.get_rbf(spent_coins_with_tx)
    rbf = txs_short.nil? ? [] : txs_short.collect{|tx| tx.tx_id}
    rbf_by = txs_long.nil? ? [] : txs_long.collect{|tx| tx.tx_id}
    rbf_total = txs_short.nil? ? 0 : txs_short.collect{|tx| tx.amount}.inject(:+)

    self.update missing_transactions: missing_transactions,
                confirmed_in_one_branch: confirmed_in_one_branch,
                confirmed_in_one_branch_total: confirmed_in_one_branch_total,
                double_spent_in_one_branch: double_spent_in_one_branch,
                double_spent_in_one_branch_total: double_spent_in_one_branch_total,
                double_spent_by: double_spent_by,
                rbf: rbf,
                rbf_by: rbf_by,
                rbf_total: rbf_total,
                height_processed: missing_transactions ? nil : tip_height
  end

  def process!
    self.fetch_transactions_for_descendants!

    # When a new block comes in (up to a maximum height) calculate the new branch
    # lengths, and scan for duplicate transactions. This is a slow operation,
    # so we wait with updating database records and expiring JSON cache until it's complete.
    ActiveRecord::Base.transaction do
      tip_height = Block.where(coin: self.coin).maximum(:height)
      if self.children.count == 0 ||
         self.height_processed.nil? ||
         (self.height_processed < tip_height && self.height_processed <= self.height + STALE_BLOCK_WINDOW)
        Rails.logger.info "Update #{ coin.to_s.upcase } stale candidate #{ self.height } for tip at #{ tip_height }..."
        self.set_children!
        self.set_conflicting_tx_info!(tip_height)
        self.expire_cache
      end # if
    end # transaction
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
    # Only process the 3 most recent stale candidates
    StaleCandidate.where(coin: coin).order(height: :desc).limit(3).each do |c|
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
      where(coin: coin).where("height > ?", min_height).order(height: :desc).limit(3).to_json({short: true})
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
