web: bundle exec puma
release: rake db:migrate
worker_poll_btc: bundle exec rake nodes:poll_repeat[BTC]
worker_poll_altcoins: bundle exec rake nodes:poll_repeat[TBTC,BCH,BSV]
worker_heavy_btc: bundle exec rake nodes:heavy_checks_repeat[BTC]
worker_heavy_testnet: bundle exec rake nodes:heavy_checks_repeat[TBTC]
