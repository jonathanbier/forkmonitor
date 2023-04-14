# frozen_string_literal: true

class UserMailer < ApplicationMailer
  include ActionMailer::Text

  def lag_email
    @user = params[:user]
    @lag = params[:lag]

    mail(
      to: @user.email,
      subject: "[ForkMonitor] #{@lag.node_a.name_with_version} is #{@lag.node_b.active_chaintip.block.height - @lag.node_a.active_chaintip.block.height} blocks behind #{@lag.node_b.version}"
    )
  end

  def invalid_block_email
    @user = params[:user]
    @invalid_block = params[:invalid_block]

    mail(
      to: @user.email,
      subject: "[ForkMonitor] #{@invalid_block.node.name_with_version} considers block #{@invalid_block.block.height} (#{@invalid_block.block.block_hash}) invalid"
    )
  end

  def version_bits_email
    @user = params[:user]
    @bit = params[:bit]
    @tally = params[:tally]
    @window = params[:window]
    @block = params[:block]

    mail(
      to: @user.email,
      subject: "[ForkMonitor] version bit #{@bit} was set #{@tally} times between blocks #{@block.height - @window + 1} and #{@block.height}"
    )
  end

  def stale_candidate_email
    @user = params[:user]
    @stale_candidate = params[:stale_candidate]
    @blocks = Block.where(height: @stale_candidate.height)

    mail(
      to: @user.email,
      subject: "[ForkMonitor] potential stale block at height #{@stale_candidate.height}"
    )
  end

  def inflated_block_email
    @user = params[:user]
    @inflated_block = params[:inflated_block]

    mail(
      to: @user.email,
      subject: "[ForkMonitor] #{@inflated_block.node.name_with_version} detected too much inflation in block #{@inflated_block.block.height} (#{@inflated_block.block.block_hash})"
    )
  end

  def softfork_email
    @user = params[:user]
    @softfork = params[:softfork]

    mail(
      to: @user.email,
      subject: "[ForkMonitor] #{@softfork.name.capitalize} #{@softfork.fork_type.to_s.upcase} status became #{@softfork.status} at height #{@softfork.since.to_s(:delimited)}"
    )
  end
end
