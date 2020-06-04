source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.7.1'

gem 'rails', '~> 5.2.3'
# Use Puma as the app server
gem 'puma', '~> 3.12.4'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'webpacker', '~> 4.0.7'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Rails asset pipeline
gem 'sprockets-rails'
gem 'sprockets', '~> 3.7.2' # probably easier to drop Sprockets then to upgrade

gem 'rails_real_favicon'

# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

# Ruby interface to the 'bitcoind' JSON-RPC API
gem 'bitcoiner'

# Ruby Bitcoin utilities
gem 'bitcoin-ruby', require: 'bitcoin'

gem 'rack-cors', require: 'rack/cors'

# Authentication
gem 'devise-jwt'

# Push notifications
gem 'serviceworker-rails'
gem 'webpush'

# Email when something breaks
gem 'exception_notification'
gem 'exception_notification-rake', '~> 0.3.0'

# Generate text versions of email
gem 'actionmailer-text'

# There is no request timeout mechanism inside of Puma.
gem "rack-timeout"

# Measure test coverage
gem 'coveralls', require: false

# Print arrays as a table
gem 'table_print'

# ZeroMQ to communicate with libbitcoin
gem '0mq', '~> 0.5.3'

# Use Postgres as the database for Active Record
gem 'pg'

# Memcachier
gem 'dalli'

# Deployment
 gem 'capistrano', '~> 3.14'
 gem 'capistrano-rails', '~> 1.5'
 gem 'capistrano-passenger', '~> 0.2.0'
 gem 'capistrano-rbenv', '~> 2.1', '>= 2.1.6'
 gem 'ed25519'
 gem 'bcrypt_pbkdf'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'

  gem 'rspec-rails', '~> 3.8'
  gem 'factory_bot'
  gem 'ffaker'
  gem 'timecop'

  gem 'rails-controller-testing'

  # Shim to load environment variables from .env into ENV
  gem 'dotenv-rails'

  gem 'webmock'

  gem 'redis-rails'

  # Call Python, e.g. Bitcoin Core test framework (switch to 1.3.1 release when ready)
  gem 'pycall', :github => 'mrkn/pycall.rb', :ref => "b9de184825b3bd0ab7ffb991d2b2f462f55227c4"

  gem 'parallel_tests'
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'

  # Automatically run tests, etc:
  gem 'guard'
  gem 'guard-rspec', require: false
  gem 'terminal-notifier-guard', '~> 1.6.1'
end
