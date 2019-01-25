class ApplicationController < ActionController::Base
  protect_from_forgery unless: -> { request.format.json? }
  before_action :no_cookies

  private

  def no_cookies
    request.session_options[:skip] = true
  end
end
