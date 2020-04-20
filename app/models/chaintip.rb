class Chaintip < ApplicationRecord
  belongs_to :block, optional: false
  belongs_to :node, optional: false, touch: true
  belongs_to :parent_chaintip, class_name: 'Chaintip', foreign_key: 'parent_chaintip_id', optional: true, :dependent => :destroy  # When a node is behind, we assume it would agree with this chaintip, until getchaintips says otherwise
  has_many :children,  class_name: 'Chaintip', foreign_key: 'parent_chaintip_id', :dependent => :nullify

  after_commit :expire_cache

  enum coin: [:btc, :bch, :bsv, :tbtc]

  validates :status, uniqueness: { scope: :node}

  def nodes_for_identical_chaintips
    return nil if status != "active"
    chaintip_nodes = Chaintip.joins(:node).where("chaintips.status = ? AND chaintips.block_id = ?", status, self.block_id).order(client_type: :asc ,name: :asc, version: :desc)
    res = chaintip_nodes.collect{ | c | c.node }
    chaintip_nodes.each do |chaintip_node|
      chaintip_node.children.each do |child|
        Node.where("block_id = ?", child.block_id).each do |node_for_child|
          res.append node_for_child
        end
      end
    end
    # Node ordering:
    # * behind nodes at the bottom
    # * order by client type, then version
    res.uniq.sort_by{ |node| [-node.block.height, node.client_type_before_type_cast, node.name, -node.version] }
  end

  def as_json(options = nil)
    fields = [:id]
    super({ only: fields }.merge(options || {})).merge({block: block, nodes: nodes_for_identical_chaintips})
  end

  def match_parent!(node)
    # Check if any of the other nodes are ahead of us. Use their chaintip instead unless we consider it invalid:
    Chaintip.joins(:block).where(coin: self.coin, status: "active").where("blocks.height > ?", block.height).each do |candidate_tip|
      # Travers candidate tip down to find our tip
      parent = candidate_tip.block
      while parent.present? && parent.height >= block.height
        if node.chaintips.find_by(block: parent, status: "invalid")
          self.update parent_chaintip: nil
          break
        end
        if parent == block
          self.update parent_chaintip: candidate_tip
          break
        end
        parent = parent.parent
      end
      break if self.parent_chaintip
    end
  end

  def match_children!(node)
    # Check if any of the other nodes are behind of us. Mark us their parent chaintip, unless they consider us invalid.
    Chaintip.joins(:block).where(coin: self.coin, status: "active").where("blocks.height < ?", block.height).each do |candidate_tip|
      # Travers down from ourselfves to find candidate tip
      parent = self.block
      while parent.present? && parent.height >= candidate_tip.block.height
        break if node.chaintips.find_by(block: parent, status: "invalid")
        if parent == candidate_tip.block
          candidate_tip.update parent_chaintip: self
          break
        end
        parent = parent.parent
      end
      break if candidate_tip.parent_chaintip
    end
  end

  def self.process_chaintip_result(chaintip, node)
    block = Block.find_by(block_hash: chaintip["hash"], coin: node.coin.downcase.to_sym)
    case chaintip["status"]
    when "active"
      # A block may have arrived between when we called getblockchaininfo and getchaintips.
      # In that case, ignore the new chaintip and get back to it later.
      return nil unless block.present?
      block.update marked_valid_by: block.marked_valid_by.push(node.id)
      tip = Chaintip.process_active!(node, block)
    when "valid-fork"
      return nil if chaintip["height"] < node.block.height - (Rails.env.test? ? 1000 : 10)
      block = Block.find_or_create_block_and_ancestors!(chaintip["hash"], node, false, true)
      tip = node.chaintips.create(status: "valid-fork", block: block, coin: block.coin) # There can be multiple valid-block chaintips
      block.update marked_valid_by: block.marked_valid_by | [node.id]
    when "invalid"
      block = Block.find_or_create_block_and_ancestors!(chaintip["hash"], node, false, false)
      block.update marked_invalid_by: block.marked_invalid_by | [node.id]
      tip = node.chaintips.create(status: "invalid", block: block, coin: block.coin)
    end
  end

  def self.process_getchaintips(chaintips, node)
     chaintips.each do |chaintip|
       process_chaintip_result(chaintip, node)
     end
   end

   # Update the existing active chaintip or create a fresh one. Then update parents and children.
   def self.process_active!(node, block)
     tip = Chaintip.find_or_initialize_by(coin: block.coin, node: node, status: "active")
     if tip.block != block
       tip.block = block
       tip.parent_chaintip = nil
       tip.children.each do |child|
         child.parent_chaintip = nil
       end
     end
     tip.save
     return tip
   end

  def self.check!(coin, nodes)
    # Delete existing (non-active chaintips)
    nodes.each do |node|
      Chaintip.purge!(node)
    end

    # In order to keep the database transaction lock as short as possible,
    # we first fetch chaintip info from all nodes, and then process that.
    chaintip_sets = nodes.collect { |node|
      node.reload
      {
        node: node,
        chaintips: Chaintip.fetch!(node)
      }
    }
    Chaintip.transaction {
      result = chaintip_sets.collect { |set|
        if set[:chaintips].present?
          Chaintip.process_getchaintips(set[:chaintips], set[:node])
        end
      }
      # Match children and parent active chaintips
      nodes.each do |node|
        Chaintip.where(node: node).where(status: "active").each do |chaintip|
          chaintip.match_children!(node)
          chaintip.match_parent!(node)
        end
      end
      Node.prune_empty_chaintips!(coin)
    }
  end

  def self.purge!(node)
    if node.unreachable_since || node.ibd || node.block.nil?
      # Remove cached chaintips from db and return nil if node is unreachbale or in IBD:
      Chaintip.where(node: node).destroy_all
    else
      # Delete existing chaintip entries, except the active one (which might be unchanged):
      Chaintip.where(node: node).where.not(status: "active").destroy_all
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
  def self.fetch!(node)
    if node.unreachable_since || node.ibd || node.block.nil?
      return nil
    else
      # libbitcoin, btcd and older Bitcoin Core versions don't implement getchaintips, so we mock it:
      if node.client_type.to_sym == :libbitcoin ||
         node.client_type.to_sym == :btcd ||
         (node.client_type.to_sym == :core && node.version.present? && node.version < 100000)

        Chaintip.process_active!(node, node.block)
        return nil
      end
    end

    begin
      return node.client.getchaintips
    rescue BitcoinClient::Error
      # Assuming this node doesn't implement it
      return nil
    end
  end

  private

  def expire_cache
    Rails.cache.delete("Chaintip.#{self.coin}.index.json")
  end

end
