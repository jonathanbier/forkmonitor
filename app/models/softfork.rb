# frozen_string_literal: true

class Softfork < ApplicationRecord
  enum coin: %i[btc bch bsv tbtc]
  enum fork_type: %i[bip9 bip8]
  enum status: %i[defined started locked_in active failed must_signal]
  belongs_to :node

  def as_json(_options = nil)
    super({ only: %i[id name bit status] }).merge({
                                                    fork_type: fork_type.upcase,
                                                    node_name: node.name_with_version,
                                                    height: self.defined? ? nil : since
                                                  })
  end

  def notify!
    if notified_at.nil?
      User.all.each do |user|
        UserMailer.with(user: user, softfork: self).softfork_email.deliver
      end
      update notified_at: Time.now
      Subscription.blast("softfork-#{id}",
                         "#{coin.upcase} #{name} softfork #{status}",
                         "#{name.capitalize} #{fork_type.to_s.upcase} status became #{status.to_s.upcase} at height #{since.to_s(:delimited)} according to #{node.name_with_version}.")
    end
  end

  def self.notify!
    Softfork.where(notified_at: nil).each(&:notify!)
  end

  # Only supported on Bitcoin mainnet
  # Only tested with v0.18.1 and up
  def self.process(node, blockchaininfo)
    if node.version < 190_000
      return if blockchaininfo['bip9_softforks'].nil?

      blockchaininfo['bip9_softforks'].each do |key, value|
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
            status: value['status'].to_sym,
            since: value['since'],
            notified_at: value['status'].to_sym == :defined ? Time.now : nil
          )
        else
          fork.status = value['status'].to_sym
          fork.since = value['since']
          fork.notified_at = nil if fork.status_changed?
          fork.save if fork.changed?
        end
      end
    else
      return if blockchaininfo['softforks'].nil?

      blockchaininfo['softforks'].each do |key, value|
        if value['bip9'].present?
          bip9 = value['bip9']
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
              bit: bip9['bit'],
              status: bip9['status'].to_sym,
              since: bip9['since'],
              notified_at: bip9['status'].to_sym == :defined ? Time.now : nil
            )
          else
            fork.bit = bip9['bit'] # in case a node is upgraded to 0.19 or newer
            fork.status = bip9['status'].to_sym
            fork.since = bip9['since']
            fork.notified_at = nil if fork.status_changed?
            fork.save if fork.changed?
          end
        end
        next unless value['bip8'].present?

        bip8 = value['bip8']
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
            bit: bip8['bit'],
            status: bip8['status'].to_sym,
            since: bip8['since'],
            notified_at: bip8['status'].to_sym == :defined ? Time.now : nil
          )
        else
          fork.bit = bip8['bit'] # in case a node is upgraded to 0.19 or newer
          fork.status = bip8['status'].to_sym
          fork.since = bip8['since']
          fork.notified_at = nil if fork.status_changed?
          fork.save if fork.changed?
        end
      end
    end
  end
end
