class ApplicationController < ActionController::Base
  protect_from_forgery unless: -> { request.format.json? }
  before_action :no_cookies

  private

  def no_cookies
    request.session_options[:skip] = true
  end

  def set_coin
    @coin = params[:coin].downcase.to_sym
    unless params[:coin].present? && Node::SUPPORTED_COINS.include?(@coin)
      render json: "invalid param", status: :unprocessable_entity
      return
    end
  end

  def set_coin_optional
    set_coin if params[:coin].present?
  end

end
