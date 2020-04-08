Rails.application.configure do
  config.assets.precompile += %w[serviceworker.js]
end
