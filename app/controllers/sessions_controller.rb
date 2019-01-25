class SessionsController < Devise::SessionsController
  respond_to :json
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }

  before_action :no_cookies

  private

  def no_cookies
    request.session_options[:skip] = true
  end

  def respond_with(resource, _opts = {})
    render json: {token: current_token}
  end

  def respond_to_on_destroy
    head :no_content
  end

  def current_token
   request.env['warden-jwt_auth.token']
 end
end
