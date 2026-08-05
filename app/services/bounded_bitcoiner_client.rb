# frozen_string_literal: true

# Adds libcurl-level timeouts to Bitcoiner's HTTP requests. Unlike wrapping a
# request in Timeout.timeout, these timeouts stop the underlying transfer and
# release its socket.
class BoundedBitcoinerClient < Bitcoiner::Client
  DEFAULT_CONNECT_TIMEOUT = 30

  def initialize(...)
    super
    @request_mutex = Mutex.new
  end

  def request(method_or_array_of_methods, *args, timeout: nil)
    @request_mutex.synchronize do
      @request_timeout = timeout
      super(method_or_array_of_methods, *args)
    ensure
      @request_timeout = nil
    end
  end

  private

  def post(body)
    message = {
      endpoint: endpoint,
      username: username,
      body: body.to_json
    }.to_s
    log(message)

    options = {
      userpwd: [username, password].join(':'),
      body: body.to_json,
      connecttimeout: [@request_timeout || DEFAULT_CONNECT_TIMEOUT, DEFAULT_CONNECT_TIMEOUT].min
    }
    options[:timeout] = @request_timeout if @request_timeout

    Typhoeus.post(endpoint, options)
  end
end
