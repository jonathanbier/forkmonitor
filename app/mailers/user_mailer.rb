class UserMailer < ApplicationMailer
  def lag_email
    @user = params[:user]
    @lag = params[:lag]

    mail(
      to: @user.email,
      subject: "[ForkMonitor] #{ @lag.node_a.name_with_version } is #{ @lag.node_b.block.height - @lag.node_a.block.height } blocks behind #{ @lag.node_b.version }"
    )
  end

  def invalid_block_email
    @user = params[:user]
    @invalid_block = params[:invalid_block]

    mail(
      to: @user.email,
      subject: "[ForkMonitor] #{ @invalid_block.node.name_with_version } considers block #{ @invalid_block.block.height } (#{ @invalid_block.block.block_hash }) invalid"
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
      subject: "[ForkMonitor] version bit #{ @bit } was set #{ @tally } times between blocks #{ @block.height - @window + 1 } and #{ @block.height }"
    )
  end

  def orphan_candidate_email
    @user = params[:user]
    @orphan_candidate = params[:orphan_candidate]
    @blocks = Block.where(coin: :btc, height: @orphan_candidate.height)

    mail(
      to: @user.email,
      subject: "[ForkMonitor] potential orphan block at height #{ @orphan_candidate.height }"
    )
  end
end
