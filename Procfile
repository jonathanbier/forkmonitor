web: bundle exec puma
release: rake db:migrate
worker1: bundle exec rake nodes:poll_repeat[BTC]
worker2: bundle exec rake nodes:poll_repeat[TBTC,BCH,BSV]
worker3: bundle exec rake nodes:heavy_checks_repeat[BTC]
worker4: bundle exec rake nodes:heavy_checks_repeat[TBTC]
