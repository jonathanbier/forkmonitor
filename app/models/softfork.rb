class Softfork < ApplicationRecord
  enum coin: [:btc, :bch, :bsv, :tbtc]
  enum fork_type: [:bip9]
  enum status: [:defined, :started, :locked_in, :active, :failed]
  belongs_to :node

  def as_json(options = nil)
    super({ only: [:type, :name, :bit, :status, :since]})
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
            since: value["since"]
          )
        else
          fork.status = value["status"].to_sym
          fork.since = value["since"]
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
              since: bip9["since"]
            )
          else
            fork.bit = bip9["bit"] # in case a node is upgraded to 0.19 or newer
            fork.status = bip9["status"].to_sym
            fork.since = bip9["since"]
            fork.save if fork.changed?
          end
        end
      end
    end
  end
end
