class UserMailer < ApplicationMailer
  def lag_email
    @user = params[:user]
    @lag = params[:lag]

    mail(
      to: @user.email,
      subject: "[ForkMonitor] #{ @lag.node_a.name } #{ @lag.node_a.version } is #{ @lag.node_b.block.height - @lag.node_a.block.height } blocks behind #{ @lag.node_b.version }"
    )
  end
end
