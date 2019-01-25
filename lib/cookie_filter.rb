# class CookieFilter
#   def initialize(app)
#     @app = app
#   end
#
#   def call(env)
#     status, headers, body = @app.call(env)
#
#     # this will remove ALL cookies from the response
#     # headers.delete 'Set-Cookie'
#
#     Rack::Utils.delete_cookie_header!(headers, '_fork_monitor_session')
#
#     [status, headers, body]
#   end
# end
