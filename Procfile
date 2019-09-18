web: bundle exec puma
release: rake db:migrate
worker: bundle exec rake nodes:poll_repeat[BTC]
worker: bundle exec rake nodes:poll_repeat[TBTC,BCH,BSV]
