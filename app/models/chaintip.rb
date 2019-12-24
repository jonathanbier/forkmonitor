class Chaintip < ApplicationRecord
  belongs_to :block, optional: false
  belongs_to :node, optional: false
  belongs_to :parent_chaintip, class_name: 'Chaintip', foreign_key: 'parent_chaintip_id', optional: true, :dependent => :destroy  # When a node is behind, we assume it would agree with this chaintip, until getchaintips says otherwise
  has_many :children,  class_name: 'Chaintip', foreign_key: 'parent_chaintip_id', :dependent => :nullify

  after_save    :expire_cache
  after_destroy :expire_cache

  enum coin: [:btc, :bch, :bsv, :tbtc]

  validates :status, uniqueness: { scope: :node}

  def nodes_for_identical_chaintips
    return nil if status != "active"
    chaintip_nodes = Chaintip.joins(:node).where("chaintips.status = ? AND chaintips.block_id = ?", status, self.block_id).order(client_type: :asc ,name: :asc, version: :desc)
    res = chaintip_nodes.collect{ | c | c.node }
    chaintip_nodes.each do |chaintip_node|
      chaintip_node.children.each do |child|
        Node.where("block_id = ?", child.block_id).order(client_type: :asc ,name: :asc, version: :desc).each do |node_for_child|
          res.append node_for_child
        end
      end
    end
    # Node ordering:
    # * behind nodes at the bottom
    # * order by client type, then version (done above)
    res.uniq.sort_by { |node| -node.block.height }
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
      tip = Chaintip.process_active!(node, block)
    when "valid-fork"
      return nil if chaintip["height"] < node.block.height - 1000
      block = Block.find_or_create_block_and_ancestors!(chaintip["hash"], node, false)
      tip = node.chaintips.create(status: "valid-fork", block: block, coin: block.coin) # There can be multiple valid-block chaintips
    when "invalid"
      # Ignore if we don't know this block from a different node: (TODO: add it anyway, so we actively search this block)
      return nil if block.nil?

      tip = node.chaintips.create(status: "invalid", block: block, coin: block.coin)

      # Create an alert
      invalid_block = InvalidBlock.find_or_create_by(node: node, block: block)
      if !invalid_block.notified_at
        User.all.each do |user|
          UserMailer.with(user: user, invalid_block: invalid_block).invalid_block_email.deliver
        end
        invalid_block.update notified_at: Time.now
        Subscription.blast("invalid-block-#{ invalid_block.id }",
                           "Invalid block",
                           "#{ invalid_block.node.name_with_version } considers #{ invalid_block.block.coin.upcase } block { @invalid_block.block.height } ({ @invalid_block.block.block_hash }) invalid",
        )
      end
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
     tip.match_children!(node)
     tip.match_parent!(node)
     return tip
   end

  private

  def expire_cache
    Rails.cache.delete("Chaintip.#{self.coin}.index.json")
  end

end
