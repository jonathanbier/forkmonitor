# frozen_string_literal: true

class StaleCandidate < ApplicationRecord
  PER_PAGE = Rails.env.production? ? 100 : 2
  DOUBLE_SPEND_RANGE = Rails.env.production? ? 30 : 10
  STALE_BLOCK_WINDOW = Rails.env.test? ? 5 : 100

  enum coin: { btc: 0, bch: 1, bsv: 2, tbtc: 3 }

  has_many :children, class_name: 'StaleCandidateChild', dependent: :destroy

  scope :feed, lambda {
    # RSS feed switched to new GUID. Drop old items to prevent spurious notifications.
    where(
      'created_at >= ?', DateTime.civil_from_format(:local, 2020, 7, 15)
    )
  }

  def as_json(options = nil)
    if options[:short]
      super({ only: %i[coin height n_children] })
    else
      super({ only: %i[coin height n_children] }).merge({
                                                          children: children.sort_by do |c|
                                                                      c.root.timestamp || c.root.created_at.to_i
                                                                    end,
                                                          headers_only: children.any? { |c| c.root.headers_only }
                                                        })
    end
  end

  def json_cached
    cache_key = "StaleCandidate(#{id}).json"

    Rails.cache.fetch(cache_key) do
      to_json
    end
  end

  # Exclude double_spent_in_one_branch
  def confirmed_in_one_branch_txs
    Transaction.where('tx_id in (?)',
                      confirmed_in_one_branch - double_spent_in_one_branch).select('tx_id, max(amount) as amount').group(:tx_id).order('amount DESC')
  end

  def double_spent_in_one_branch_txs
    Transaction.where('tx_id in (?)',
                      double_spent_in_one_branch - rbf).select('tx_id, max(amount) as amount').group(:tx_id).order('amount DESC')
  end

  def double_spent_by_txs
    Transaction.where('tx_id in (?)',
                      double_spent_by - rbf_by).select('tx_id, max(amount) as amount').group(:tx_id).order('amount DESC')
  end

  def rbf_txs
    Transaction.where('tx_id in (?)', rbf).select('tx_id, max(amount) as amount').group(:tx_id).order('amount DESC')
  end

  def rbf_by_txs
    Transaction.where('tx_id in (?)', rbf_by).select('tx_id, max(amount) as amount').group(:tx_id).order('amount DESC')
  end

  def double_spend_info
    {
      height_processed: height_processed,
      n_children: children.count,
      children: children,
      missing_transactions: missing_transactions,
      confirmed_in_one_branch: confirmed_in_one_branch_txs,
      confirmed_in_one_branch_total: (confirmed_in_one_branch_total || 0) - (double_spent_in_one_branch_total || 0),
      double_spent_in_one_branch: double_spent_in_one_branch_txs,
      double_spent_by: double_spent_by_txs,
      double_spent_in_one_branch_total: (double_spent_in_one_branch_total || 0) - (rbf_total || 0),
      rbf: rbf_txs,
      rbf_by: rbf_by_txs,
      rbf_total: rbf_total,
      headers_only: children.any? { |child| child.root.headers_only }
    }.to_json
  end

  def double_spend_info_cached
    cache_key = "StaleCandidate(#{id})/double_spend_info.json"
    return nil if height_processed.nil?

    Rails.cache.fetch(cache_key) do
      double_spend_info
    end
  end

  def get_confirmed_in_one_branch
    return nil if children.length < 2
    # TODO: handle more than 2 branches:
    return nil if children.length > 2

    # If branches are of different length, potential double spends are transactions
    # in the shortest chain that are missing in the longest chain.
    (shortest, longest) = children.sort_by(&:length)
    return nil if shortest.root.headers_only || longest.root.headers_only
    # Ensure we have transactions for all child blocks
    return nil if ([shortest.root] + shortest.root.descendants(DOUBLE_SPEND_RANGE)).any? do |block|
                    block.transactions.count.zero?
                  end
    return nil if ([longest.root] + longest.root.descendants(DOUBLE_SPEND_RANGE)).any? do |block|
                    block.transactions.count.zero?
                  end

    shortest_tx_ids = shortest.root.block_and_descendant_transaction_ids(DOUBLE_SPEND_RANGE)
    longest_tx_ids = longest.root.block_and_descendant_transaction_ids(DOUBLE_SPEND_RANGE)
    if shortest.length < longest.length
      # Transactions that were created on the shortest side, but not on the longest:
      shortest_tx_ids - longest_tx_ids
    else
      # If both branches are the same length, consider unique transactions on either side:
      (shortest_tx_ids - longest_tx_ids) | (longest_tx_ids - shortest_tx_ids)
    end

    # Return transaction details (database id is omitted)
  end

  def get_spent_coins_with_tx
    return nil if children.length < 2
    # TODO: handle more than 2 branches:
    return nil if children.length > 2

    # If branches are of different length, double spends are inputs spent
    # in the shortest chain that also spent by a different transaction in the longest chain
    (shortest, longest) = children.sort_by(&:length)
    return nil if shortest.root.headers_only || longest.root.headers_only

    shortest_txs = shortest.root.block_and_descendant_transactions(DOUBLE_SPEND_RANGE)
    longest_txs = longest.root.block_and_descendant_transactions(DOUBLE_SPEND_RANGE)
    return nil if shortest_txs.nil? || longest_txs.nil?

    longest_spent_coins_with_tx = longest_txs.collect(&:spent_coins_map).inject(&:merge)
    shortest_spent_coins_with_tx = shortest_txs.collect(&:spent_coins_map).inject(&:merge)
    return nil if longest_spent_coins_with_tx.nil? || shortest_spent_coins_with_tx.nil?

    [shortest_spent_coins_with_tx, longest_spent_coins_with_tx]
  end

  def get_double_spent_inputs(spent_coins_with_tx)
    return nil if spent_coins_with_tx.nil?

    (shortest_spent_coins_with_tx, longest_spent_coins_with_tx) = spent_coins_with_tx

    # Filter coins that are spent with a different tx in the longest chain
    # unique is used because a transaction may doublespend multiple inputs
    shortest_spent_coins_with_tx.filter do |txout, tx|
      longest_spent_coins_with_tx.key?(txout) && tx.tx_id != longest_spent_coins_with_tx[txout].tx_id
    end.collect { |txout, tx| [tx, longest_spent_coins_with_tx[txout]] }.uniq.transpose
  end

  def get_rbf(spent_coins_with_tx)
    return nil if spent_coins_with_tx.nil?

    (shortest_spent_coins_with_tx, longest_spent_coins_with_tx) = spent_coins_with_tx

    # Filter coins that are spent with a different tx in the longest chain
    shortest_spent_coins_with_tx.filter do |txout, tx|
      if !longest_spent_coins_with_tx.key?(txout) || tx.tx_id == longest_spent_coins_with_tx[txout].tx_id
        false
      else
        # Check for fee bump (regardless of RBF flag):
        # Check that:
        # * the number of destinations is the same
        # * none of the destinations changed
        # * none of the outputs varied by more than 0.0001 BTC
        # TODO:
        # * don't sort by output; it's brittle. Just check if the same output
        #   exists on the other side.
        # * be more flexible if a change output is added
        replacement = longest_spent_coins_with_tx[txout]
        # puts "#{ tx.tx_id } vs #{ replacement.tx_id }"
        sorted_outputs = tx.outputs.sort_by(&:pk_script)
        replacement_sorted_outputs = replacement.outputs.sort_by(&:pk_script)
        if sorted_outputs.length == replacement_sorted_outputs.length
          sorted_outputs.map.with_index do |output, i|
            # puts "#{i}: #{ output.pk_script == replacement_sorted_outputs[i].pk_script } #{ (output.value - replacement_sorted_outputs[i].value).abs }"
            output.pk_script != replacement_sorted_outputs[i].pk_script ||
              (output.value - replacement_sorted_outputs[i].value).abs > 10_000
          end.none? { |res| res }
        else
          false
        end
      end
    end.collect { |txout, tx| [tx, longest_spent_coins_with_tx[txout]] }.uniq.transpose
  end

  def expire_cache
    Rails.cache.delete("StaleCandidate(#{id}).json")
    Rails.cache.delete("StaleCandidate(#{id})/double_spend_info.json")
    Rails.cache.delete("StaleCandidate.index.for_coin(#{coin}).json")
    Rails.cache.delete("StaleCandidate.last_updated(#{coin})")
    (1...((StaleCandidate.feed.count / PER_PAGE) + 1)).each do |page|
      Rails.cache.delete("StaleCandidate.feed.for_coin(#{coin},#{page})")
    end
    Rails.cache.delete("StaleCandidate.feed.count(#{coin})")
  end

  def fetch_transactions_for_descendants!
    # Iterate over descendant blocks to add their transactions
    Block.where(coin: coin, height: height).find_each do |candidate_block|
      candidate_block.fetch_transactions!
      candidate_block.descendants.where('height <= ?', height + DOUBLE_SPEND_RANGE).find_each(&:fetch_transactions!)
    end
  end

  def set_children!
    children.destroy_all # TODO: update records instead
    Block.where(coin: coin, height: height).find_each do |root|
      chain = Block.where('height <= ?', height + STALE_BLOCK_WINDOW).join_recursive do
        start_with(block_hash: root.block_hash)
          .connect_by(id: :parent_id)
          .order_siblings(:work)
      end
      tip = chain[-1]
      children.create(
        root: root,
        tip: tip,
        length: chain.count
      )
    end
  end

  def set_conflicting_tx_info!(tip_height)
    Rails.logger.info "Prime confirmed in one branch cache for #{coin.to_s.upcase} stale candidate #{height}..."
    missing_transactions = false
    update n_children: children.count
    confirmed_in_one_branch = get_confirmed_in_one_branch
    # TODO: check missing_transactions seperately and avoid expensive calls below
    if confirmed_in_one_branch.nil?
      confirmed_in_one_branch = []
      missing_transactions = true
    end
    confirmed_in_one_branch_total = if confirmed_in_one_branch.count.zero?
                                      0
                                    else
                                      Transaction.where('tx_id in (?)',
                                                        confirmed_in_one_branch).select('tx_id, max(amount) as amount').group(:tx_id).collect(&:amount).inject(:+)
                                    end
    Rails.logger.info "Prime doublespend cache for #{coin.to_s.upcase} stale candidate #{height}..."
    spent_coins_with_tx = get_spent_coins_with_tx
    txs_short, txs_long = get_double_spent_inputs(spent_coins_with_tx)
    double_spent_in_one_branch = txs_short.nil? ? [] : txs_short.collect(&:tx_id)
    double_spent_in_one_branch_total = txs_short.nil? ? 0 : txs_short.collect(&:amount).inject(:+)
    double_spent_by = txs_long.nil? ? [] : txs_long.collect(&:tx_id)
    Rails.logger.info "Prime fee-bump cache for #{coin.to_s.upcase} stale candidate #{height}..."
    txs_short, txs_long = get_rbf(spent_coins_with_tx)
    rbf = txs_short.nil? ? [] : txs_short.collect(&:tx_id)
    rbf_by = txs_long.nil? ? [] : txs_long.collect(&:tx_id)
    rbf_total = txs_short.nil? ? 0 : txs_short.collect(&:amount).inject(:+)

    update missing_transactions: missing_transactions,
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
    return if bsv? # Do not fetch a full BSV block

    fetch_transactions_for_descendants!

    # When a new block comes in (up to a maximum height) calculate the new branch
    # lengths, and scan for duplicate transactions. This is a slow operation,
    # so we wait with updating database records and expiring JSON cache until it's complete.
    ActiveRecord::Base.transaction do
      tip_height = Block.where(coin: coin).maximum(:height)
      if children.count.zero? ||
         height_processed.nil? ||
         (height_processed < tip_height && height_processed <= height + STALE_BLOCK_WINDOW)
        Rails.logger.info "Update #{coin.to_s.upcase} stale candidate #{height} for tip at #{tip_height}..."
        set_children!
        set_conflicting_tx_info!(tip_height)
        expire_cache
      end
    end
  end

  def notify!
    if notified_at.nil?
      User.all.find_each do |user|
        UserMailer.with(user: user, stale_candidate: self).stale_candidate_email.deliver unless tbtc? # skip email notification for testnet
      end
      update notified_at: Time.zone.now
      unless tbtc? # skip push notification for testnet
        Subscription.blast("stale-candidate-#{id}",
                           "#{coin.upcase} stale candidate",
                           "At height #{height}")
      end
    end
  end

  def prime_cache
    return false if Rails.cache.exist?("StaleCandidate(#{id}).json")

    json_cached
    double_spend_info_cached
    true
  end

  class << self
    def check!(coin)
      # Look for potential stale blocks, i.e. more than one block at the same height
      tip_height = Block.where(coin: coin).maximum(:height)
      return if tip_height.nil?

      Block.select(:height).where(coin: coin).where('height > ?',
                                                    tip_height - STALE_BLOCK_WINDOW).group(:height).having('count(height) > 1').order(height: :asc).each do |block|
        # If there are is more than 1 block at the previous height, assume we already have a stale block entry:
        next if Block.where(coin: coin, height: block.height - 1).count > 1
        # If there was an invalid block, assume there's fork:
        # TODO: check the chaintips; perhaps there's both a fork and a stale block on one side
        #       until then, we assume a forked node is deleted and the alert is dismissed
        next if InvalidBlock.joins(:block).where(dismissed_at: nil).where('blocks.coin = ?',
                                                                          Block.coins[coin]).count.positive?

        stale_candidate = find_or_generate(coin, block.height)
        stale_candidate.notify!
      end
    end

    def find_or_generate(coin, height)
      throw "Expected at least two #{coin} blocks at height #{height}" unless Block.where(coin: coin,
                                                                                          height: height).count > 1
      s = StaleCandidate.create_with(n_children: Block.where(coin: coin, height: height).count).find_or_create_by(
        coin: coin, height: height
      )
      # Fetch transactions for all blocks at this height
      return s if coin == :bsv # Never fetch a full BSV block

      Block.where(coin: coin, height: height).find_each(&:fetch_transactions!)
      s
    end

    def process!(coin)
      # Only process the 3 most recent stale candidates
      StaleCandidate.where(coin: coin).order(height: :desc).limit(3).each(&:process!)
    end

    def prime_cache(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      unless Rails.cache.exist?("StaleCandidate.index.for_coin(#{coin}).json")
        Rails.logger.info "Prime stale candidate index for #{coin.to_s.upcase}..."
        StaleCandidate.index_json_cached(coin)
      end

      min_height = Block.where(coin: coin).maximum(:height) - 20_000
      StaleCandidate.where(coin: coin).where('height > ?', min_height).order(height: :desc).each do |s|
        # Prime cache one at a time
        break if s.prime_cache
      end
    end

    def index_json_cached(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      Rails.cache.fetch("StaleCandidate.index.for_coin(#{coin}).json") do
        min_height = Block.where(coin: coin).maximum(:height) - 1000
        where(coin: coin).where('height > ?', min_height).order(height: :desc).limit(3).to_json({ short: true })
      end
    end

    def last_updated_cached(coin)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      Rails.cache.fetch("StaleCandidate.last_updated(#{coin})") do
        where(coin: coin).order(updated_at: :desc).first
      end
    end

    def page_cached(coin, page)
      raise BitcoinUtil::RPC::InvalidCoinError unless Rails.configuration.supported_coins.include?(coin)

      Rails.cache.fetch("StaleCandidate.feed.for_coin(#{coin},#{page})") do
        feed.where(coin: coin).order(created_at: :desc).offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
      end
    end
  end
end
