class Softfork < ApplicationRecord
  enum coin: [:btc, :bch, :bsv, :tbtc]
  enum fork_type: [:bip9, :bip8]
  enum status: [:defined, :started, :locked_in, :active, :failed, :must_signal]
  belongs_to :node

  def as_json(options = nil)
    super({ only: [:id, :name, :bit, :status]}).merge({
      fork_type: self.fork_type.upcase,
      node_name: self.node.name_with_version,
      height: self.defined? ? nil : since
    })
  end

  def notify!
    if self.notified_at.nil?
      User.all.each do |user|
        UserMailer.with(user: user, softfork: self).softfork_email.deliver
      end
      self.update notified_at: Time.now
      Subscription.blast("softfork-#{ self.id }",
                         "#{ self.coin.upcase } #{ self.name } softfork #{ self.status }",
                         "#{ self.name.capitalize } #{ self.fork_type.to_s.upcase } status became #{ self.status.to_s.upcase } at height #{ self.since.to_s(:delimited) } according to #{ self.node.name_with_version }."
      )
    end
  end

  def self.notify!
    Softfork.where(notified_at: nil).each do |softfork|
      softfork.notify!
    end
  end

  # Only supported on Bitcoin mainnet
  # Only tested with v0.18.1 and up
  def self.process(node, blockchaininfo)
    if node.version < 190000
      return if blockchaininfo["bip9_softforks"].nil?
      blockchaininfo["bip9_softforks"].each do |key, value|
        fork = Softfork.find_by(
          coin: :btc,
          node: node,
          fork_type: :bip9,
          name: key
        )
        if fork.nil?
          Softfork.create(
            coin: :btc,
            node: node,
            fork_type: :bip9,
            name: key,
            bit: nil,
            status: value["status"].to_sym,
            since: value["since"],
            notified_at: value["status"].to_sym == :defined ? Time.now : nil
          )
        else
          fork.status = value["status"].to_sym
          fork.since = value["since"]
          if fork.status_changed?
            fork.notified_at = nil
          end
          fork.save if fork.changed?
        end
      end
    else
      return if blockchaininfo["softforks"].nil?
      blockchaininfo["softforks"].each do |key, value|
        if value["bip9"].present?
          bip9 = value["bip9"]
          fork = Softfork.find_by(
            coin: :btc,
            node: node,
            fork_type: :bip9,
            name: key
          )
          if fork.nil?
            Softfork.create(
              coin: :btc,
              node: node,
              fork_type: :bip9,
              name: key,
              bit: bip9["bit"],
              status: bip9["status"].to_sym,
              since: bip9["since"],
              notified_at: bip9["status"].to_sym == :defined ? Time.now : nil
            )
          else
            fork.bit = bip9["bit"] # in case a node is upgraded to 0.19 or newer
            fork.status = bip9["status"].to_sym
            fork.since = bip9["since"]
            if fork.status_changed?
              fork.notified_at = nil
            end
            fork.save if fork.changed?
          end
        end
        if value["bip8"].present?
          bip8 = value["bip8"]
          fork = Softfork.find_by(
            coin: :btc,
            node: node,
            fork_type: :bip8,
            name: key
          )
          if fork.nil?
            Softfork.create(
              coin: :btc,
              node: node,
              fork_type: :bip8,
              name: key,
              bit: bip8["bit"],
              status: bip8["status"].to_sym,
              since: bip8["since"],
              notified_at: bip8["status"].to_sym == :defined ? Time.now : nil
            )
          else
            fork.bit = bip8["bit"] # in case a node is upgraded to 0.19 or newer
            fork.status = bip8["status"].to_sym
            fork.since = bip8["since"]
            if fork.status_changed?
              fork.notified_at = nil
            end
            fork.save if fork.changed?
          end
        end
      end
    end
  end
end
