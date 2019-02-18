class UserMailer < ApplicationMailer
  def lag_email
    @user = params[:user]
    @lag = params[:lag]

    mail(
      to: @user.email,
      subject: "[ForkMonitor] #{ @lag.node_a.name } #{ @lag.node_a.version } is #{ @lag.node_b.block.height - @lag.node_a.block.height } blocks behind #{ @lag.node_b.version }"
    )
  end

  def invalid_block_email
    @user = params[:user]
    @invalid_block = params[:invalid_block]

    mail(
      to: @user.email,
      subject: "[ForkMonitor] #{ @invalid_block.node.name } #{ @invalid_block.node.version } considers block #{ @invalid_block.block.height } (#{ @invalid_block.block.block_hash }) invalid"
    )
  end
end
