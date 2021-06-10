# frozen_string_literal: true

Rails.application.configure do
  config.assets.precompile += %w[serviceworker.js]
end
