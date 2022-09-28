# frozen_string_literal: true

class Softfork < ApplicationRecord
  enum coin: { btc: 0, bch: 1, bsv: 2, tbtc: 3 }
  enum fork_type: { bip9: 0, bip8: 1 } # rubocop:disable Naming/VariableNumber
  enum status: { defined: 0, started: 1, locked_in: 2, active: 3, failed: 4, must_signal: 5 }
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
      User.all.find_each do |user|
        UserMailer.with(user: user, softfork: self).softfork_email.deliver
      end
      update notified_at: Time.zone.now
      Subscription.blast("softfork-#{id}",
                         "#{coin.upcase} #{name} softfork #{status}",
                         "#{name.capitalize} #{fork_type.to_s.upcase} status became #{status.to_s.upcase} at height #{since.to_s(:delimited)} according to #{node.name_with_version}.")
    end
  end

  class << self
    def notify!
      Softfork.where(notified_at: nil).find_each(&:notify!)
    end

    # Only supported on Bitcoin Core v23+
    def process_deploymentinfo(node, deploymentinfo)
      return unless (node.btc? || node.tbtc?) && node.core? && node.version.present? && node.version >= 230_000

      deploymentinfo['deployments'].each do |key, value|
        process_fork(node, key, value)
      end
    end

    # Only supported on Bitcoin mainnet and testnet
    # Only tested with v0.18.1 and up
    def process(node, blockchaininfo)
      return unless node.btc? || node.tbtc?

      if node.version < 190_000
        return if blockchaininfo['bip9_softforks'].nil?

        blockchaininfo['bip9_softforks'].each do |key, value|
          fork = Softfork.find_by(
            coin: node.coin,
            node: node,
            fork_type: :bip9, # rubocop:disable Naming/VariableNumber
            name: key
          )
          if fork.nil?
            Softfork.create(
              coin: node.coin,
              node: node,
              fork_type: :bip9, # rubocop:disable Naming/VariableNumber
              name: key,
              bit: nil,
              status: value['status'].to_sym,
              since: value['since'],
              notified_at: value['status'].to_sym == :defined ? Time.zone.now : nil
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
          process_fork(node, key, value)
        end
      end
    end

    def process_fork(node, key, value)
      if value['bip9'].present?
        bip9 = value['bip9'] # rubocop:disable Naming/VariableNumber
        fork = Softfork.find_by(
          coin: node.coin,
          node: node,
          fork_type: :bip9, # rubocop:disable Naming/VariableNumber
          name: key
        )
        if fork.nil?
          Softfork.create(
            coin: node.coin,
            node: node,
            fork_type: :bip9, # rubocop:disable Naming/VariableNumber
            name: key,
            bit: bip9['bit'],
            status: bip9['status'].to_sym,
            since: bip9['since'],
            notified_at: bip9['status'].to_sym == :defined ? Time.zone.now : nil
          )
        else
          fork.bit = bip9['bit'] # in case a node is upgraded to 0.19 or newer
          fork.status = bip9['status'].to_sym
          fork.since = bip9['since']
          fork.notified_at = nil if fork.status_changed?
          fork.save if fork.changed?
        end
      end
      return if value['bip8'].blank?

      bip8 = value['bip8'] # rubocop:disable Naming/VariableNumber
      fork = Softfork.find_by(
        coin: node.coin,
        node: node,
        fork_type: :bip8, # rubocop:disable Naming/VariableNumber
        name: key
      )
      if fork.nil?
        Softfork.create(
          coin: node.coin,
          node: node,
          fork_type: :bip8, # rubocop:disable Naming/VariableNumber
          name: key,
          bit: bip8['bit'],
          status: bip8['status'].to_sym,
          since: bip8['since'],
          notified_at: bip8['status'].to_sym == :defined ? Time.zone.now : nil
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
