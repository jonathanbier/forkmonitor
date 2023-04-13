# frozen_string_literal: true

class Chaintip < ApplicationRecord
  belongs_to :block, optional: false
  belongs_to :node, optional: false, touch: true
  belongs_to :parent_chaintip, class_name: 'Chaintip', optional: true, dependent: :destroy # When a node is behind, we assume it would agree with this chaintip, until getchaintips says otherwise
  has_many :children,  class_name: 'Chaintip', foreign_key: 'parent_chaintip_id', dependent: :nullify

  after_commit :expire_cache

  enum coin: { btc: 0 }

  validates :status, uniqueness: { scope: :node }

  def nodes_for_identical_chaintips
    return nil if status != 'active'

    chaintip_nodes = Chaintip.joins(:node).where('nodes.enabled = ? AND chaintips.status = ? AND chaintips.block_id = ?', true, status, block_id).order(
      client_type: :asc, name: :asc, version: :desc
    )
    res = chaintip_nodes.collect(&:node)
    chaintip_nodes.each do |chaintip_node|
      chaintip_node.children.each do |child|
        res.append child.node if child.node.enabled
      end
    end
    # Node ordering:
    # * behind nodes at the bottom
    # * order by client type, then version
    res.uniq.sort_by do |node|
      [-node.active_chaintip.block.height, node.core? ? node.client_type_before_type_cast : 1, node.name.downcase,
       -node.version]
    end
  end

  def as_json(options = nil)
    fields = [:id]
    super({ only: fields }.merge(options || {})).merge({ block: block, nodes: nodes_for_identical_chaintips })
  end

  # If chaintip has a parent, find all invalid chaintips above it, traverse down
  # to see if it descends from us. If so, disconnect parent.
  def check_parent!(node)
    if parent_chaintip.present?
      node.chaintips.joins(:block).where(status: 'invalid').where('blocks.height > ?',
                                                                  block.height).find_each do |candidate_tip|
        # Traverse candidate tip down
        parent = candidate_tip.block
        while parent.present? && parent.height >= block.height
          if parent == block
            update parent_chaintip: nil
            break
          end
          parent = parent.parent
        end
      end
    end
  end

  def match_parent!(node)
    # If we don't already have a parent, check if any of the other nodes are ahead of us.
    # Use their chaintip instead unless we consider it invalid:
    return if parent_chaintip.present?

    Chaintip.joins(:block, :node).where(coin: coin, status: 'active').where('blocks.height > ?',
                                                                            block.height).order('client_type asc, name asc, nodes.version desc').each do |candidate_tip|
      # Traverse candidate tip down, abort if block is from a chaintip we consider
      # invalid. Abort early if we marked the block invalid.
      parent = candidate_tip.block
      while parent.present? && parent.height >= block.height
        break if parent.marked_invalid_by.include?(node.id) || node.chaintips.find_by(block: parent, status: 'invalid')

        if parent == block
          update parent_chaintip: candidate_tip
          break
        end
        parent = parent.parent
      end
      break if parent_chaintip
    end
  end

  def match_children!(node)
    # Check if any of the other nodes are behind of us. If they don't have a parent,
    # mark us their parent chaintip, unless they consider us invalid.
    Chaintip.joins(:block, :node).where(coin: coin, status: 'active', parent_chaintip: nil).where(
      'blocks.height < ?', block.height
    ).order('client_type asc, name asc, nodes.version desc').each do |candidate_tip|
      # Traverse down from ourselfves to find candidate tip
      parent = block
      while parent.present? && parent.height >= candidate_tip.block.height
        break if node.chaintips.find_by(block: parent, status: 'invalid')

        if parent == candidate_tip.block
          candidate_tip.update parent_chaintip: self
          break
        end
        parent = parent.parent
      end
      break if candidate_tip.parent_chaintip
    end
  end

  private

  def expire_cache
    Rails.cache.delete("Chaintip.#{coin}.index.json")
  end

  class << self
    def process_chaintip_result(chaintip, node)
      block = Block.find_by(block_hash: chaintip['hash'], coin: node.coin)
      case chaintip['status']
      when 'active'
        # A block may have arrived between when we called getblockchaininfo and getchaintips.
        # In that case, ignore the new chaintip and get back to it later.
        return nil if block.blank?

        block.update marked_valid_by: block.marked_valid_by | [node.id]
        Chaintip.process_active!(node, block)
      when 'headers-only'
        # Not all blocks for this branch are available, but the headers are valid
        Chaintip.process_valid_headers!(node, chaintip, block)
      when 'valid-headers' # rubocop:disable Lint/DuplicateBranch
        # All blocks are available for this branch, but they were never fully validated
        Chaintip.process_valid_headers!(node, chaintip, block)
      when 'valid-fork'
        return nil if chaintip['height'] < node.block.height - (Rails.env.test? ? 1000 : 10)

        block = Block.find_or_create_block_and_ancestors!(chaintip['hash'], node, false, true)
        node.chaintips.create(status: 'valid-fork', block: block, coin: block.coin) # There can be multiple valid-block chaintips
        block.update marked_valid_by: block.marked_valid_by | [node.id]
      when 'invalid'
        block = Block.find_or_create_block_and_ancestors!(chaintip['hash'], node, false, false)
        block.update marked_invalid_by: block.marked_invalid_by | [node.id]
        node.chaintips.create(status: 'invalid', block: block, coin: block.coin)
      end
    end

    def process_getchaintips(chaintips, node)
      chaintips.each do |chaintip|
        process_chaintip_result(chaintip, node)
      end
    end

    # Update the existing active chaintip or create a fresh one. Then update parents and children.
    def process_active!(node, block)
      tip = Chaintip.find_or_initialize_by(coin: block.coin, node: node, status: 'active')
      if tip.block != block
        tip.block = block
        tip.parent_chaintip = nil
        tip.children.each do |child|
          child.parent_chaintip = nil
        end
      end
      tip.save
      tip
    end

    def process_valid_headers!(node, chaintip, block)
      return unless block.nil?
      return if chaintip['height'] < Block::MINIMUM_BLOCK_HEIGHTS[node.coin.to_sym]
      return if Block.find_by(block_hash: chaintip['hash']).present?

      Block.create_headers_only(node, chaintip['height'], chaintip['hash'])
    end

    def check!(coin, nodes)
      # Delete existing (non-active chaintips)
      nodes.each do |node|
        Chaintip.purge!(node)
      end

      # In order to keep the database transaction lock as short as possible,
      # we first fetch chaintip info from all nodes, and then process that.
      chaintip_sets = nodes.collect do |node|
        node.reload
        {
          node: node,
          chaintips: Chaintip.fetch!(node)
        }
      end
      Chaintip.transaction do
        chaintip_sets.collect do |set|
          Chaintip.process_getchaintips(set[:chaintips], set[:node]) if set.key?(:chaintips) && !set[:chaintips].nil?
        end
        # Match children and parent active chaintips
        nodes.each do |node|
          Chaintip.where(node: node).where(status: 'active').find_each do |chaintip|
            chaintip.match_children!(node)
            # Ensure newly matched children don't consider their parent invalid
            chaintip.check_parent!(node)
            # Find parent chaintip for nodes without one (e.g. because it was removed in the previous step)
            chaintip.match_parent!(node)
          end
        end
        Node.prune_empty_chaintips!(coin)
      end
    end

    def purge!(node)
      if node.unreachable_since || node.ibd || node.block.nil?
        # Remove cached chaintips from db and return nil if node is unreachbale or in IBD:
        Chaintip.where(node: node).destroy_all
      else
        # Delete existing chaintip entries, except the active one (which might be unchanged):
        Chaintip.where(node: node).where.not(status: 'active').destroy_all
      end
    end

    # getchaintips returns all known chaintips for a node, which can be:
    # * active: the current chaintip, added to our database with poll!
    # * valid-fork: valid chain, but not the most proof-of-work
    # * valid-headers: potentially valid chain, but not fully checked due to insufficient proof-of-work
    # * headers-only: same as valid-header, but even less checking done
    # * invalid: checked and found invalid, we want to make sure other nodes don't follow this, because:
    #   1) the other nodes haven't seen it all; or
    #   2) the other nodes did see it and also consider it invalid; or
    #   3) the other nodes haven't bothered to check because it doesn't have enough proof-of-work

    # We check all invalid chaintips against the database, to see if at any point in time
    # any of our other nodes saw this block, found it to have enough proof of work
    # and considered it valid. This can normally happen under two circumstances:
    # 1. the node is unaware of a soft-fork and initially accepts a block that newer
    #    nodes reject
    # 2. the node has a consensus bug
    def fetch!(node)
      if node.unreachable_since || node.ibd || node.block.nil?
        return nil
      elsif node.libbitcoin? ||
            node.btcd? ||
            (node.core? && node.version.present? && node.version < 100_000)
        # libbitcoin, btcd and older Bitcoin Core versions don't implement getchaintips, so we mock it:
        Chaintip.process_active!(node, node.block)
        return nil
      end

      begin
        node.client.getchaintips
      rescue BitcoinUtil::RPC::TimeOutError
        node.update unreachable_since: node.unreachable_since || DateTime.now
        nil
      rescue BitcoinUtil::RPC::Error
        # Assuming this node doesn't implement it
        nil
      end
    end

    def validate_forks!(node, max_depth)
      raise 'Only implemented for (modern) Bitcoin Core nodes' unless node.core? && node.version >= 100_000
      return nil if node.unreachable_since || node.ibd || node.mirror_ibd

      return nil unless node.mirror_rest_until.nil? || node.mirror_rest_until < Time.zone.now

      chaintips = nil
      begin
        chaintips = node.client.getchaintips
      rescue BitcoinUtil::RPC::TimeOutError
        node.update unreachable_since: node.unreachable_since || DateTime.now
        return nil
      end

      active_tip_height = chaintips.filter { |t| t['status'] == 'active' }.first['height']
      chaintips.filter { |t| t['status'] == 'valid-headers' }.each do |tip|
        break if tip['height'] < active_tip_height - max_depth

        block = Block.find_by(block_hash: tip['hash'])
        break if block.nil?

        block.validate_fork!(node)
      end
    end
  end
end
