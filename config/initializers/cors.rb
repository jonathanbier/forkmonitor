Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    resource '*',
             headers: :any,
             expose: ['Authorization', 'Content-Range'],
             methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
