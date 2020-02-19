# Fork Monitor [![Build Status](https://travis-ci.org/BitMEXResearch/forkmonitor.svg?branch=master)](https://travis-ci.org/BitMEXResearch/forkmonitor) [![Coverage Status](https://coveralls.io/repos/github/BitMEXResearch/forkmonitor/badge.svg?branch=master)](https://coveralls.io/github/BitMEXResearch/forkmonitor?branch=master)

## Development

Install ZeroMQ (for Libbitcoin), e.g. on macOS: `brew install zeromq`

Install Postgres, e.g. on macOS: `brew install postgresql`

Install Redis, e.g. on macOS: `brew install redis` and see [instructions](https://medium.com/@petehouston/install-and-config-redis-on-mac-os-x-via-homebrew-eb8df9a4f298).

Install Python. When using pyenv, use `env PYTHON_CONFIGURE_OPTS='--enable-shared' pyenv install VERSION` in order for [PyCall](https://github.com/mrkn/pycall.rb) to work.

Install Ruby 2.6.3 through a version manager such as [RVM](https://rvm.io) or [rbenv](https://github.com/rbenv/rbenv). Install
the bundler and foreman gems, then run bundler:

```
gem install bundler foreman
bundle install --without production
```

You also need [Yarn](https://yarnpkg.com/lang/en/docs/install/#mac-stable), a package
manager for NodeJS. Once installed, run:

```
yarn
```

Run `rake secret` and then edit `.env` to add it:

```
DEVISE_JWT_SECRET_KEY=the_generate_secret
```

Now run the server (this can take a while the first time, as well as each time you modify javascript):

```
foreman start -f Procfile.dev -p 3000
```

To check if nodes are reachable:

```
rake debug:node_info
```

To poll nodes:

```
rake nodes:poll
rake nodes:poll[BTC,TBTC]
```

To poll all nodes continuously, or filter by coin:

```sh
rake nodes:poll_repeat
rake nodes:poll_repeat[BTC,TBTC]
```

To check inflation, you need to run a mirror node and add it in the admin panel.

```
rake blocks:check_inflation[BTC]
```

To run inflation checks continuously, filtered by coin:
```
rake nodes:heavy_checks_repeat[BTC]
```

To manually query a node:

```rb
rails c
info = Node.first.client.getblockchaininfo
info["blocks"]
=> 548121
```

To get the list of RPC commands and execute an arbitrary command:

```rb
puts Node.first.client.help
Node.first.client.request("getblock", ...)
```

To communicate with the first Bitcoin Core mirror node:

```
Node.where(coin:"BTC").where.not(mirror_rpchost: nil).first.mirror_client.getchaintips
```

## Test suite

Some of the tests require (a specific version of) Bitcoin Core. To install:

```
cd vendor/bitcoin
cp ../bitcoin-config.ini test/config.ini
contrib/devtools/previous_release.sh -b -t .. v0.19.0.1
```

Edit `bitcoin/test/config.ini` and replace `$TRAVIS_BUILD_DIR` with the root path
of this project.

To run Rails tests and monitor for changes:

```sh
guard
<hit enter>
```

To run Rails tests in parallel (optionally set `PARALLEL_TEST_PROCESSORS`):

```sh
rake parallel:create
rake parallel:prepare
rake parallel:spec
```

To run Javascript tests and monitor for changes:

```sh
yarn test --watch
```

## Tools

To get a list of chaintips for all nodes run:

```rb
rake blocks:get_chaintips
```

```
Node 1: Bitcoin Core 0.17.99:
HEIGHT | BRANCHLEN | STATUS        | HASH
-------|-----------|---------------|-----------------------------------------------------------------
572319 | 0         | active        | 0000000000000000002671de2c0d7966398eef6c36e5c23706e36f2b6ba34633
525890 | 1         | valid-headers | 0000000000000000003d068ec400b1042b8d1ed867cf3c380b64ca074c6d12c7
```

To investigate stale blocks (`valid-fork`), use the node id and chaintip hash from above:

```rb
rake blocks:investigate_chaintip[NODE_ID,CHAINTIP_HASH]
```

## Push notifications

Generate a `VAPID_PUBLIC_KEY` and `VAPID_PRIVATEY_KEY` for push notifications:

```rb
npm install -g web-push
web-push generate-vapid-keys
```

Also provide a contact email via `VAPID_CONTACT_EMAIL=`.

To test notifications, open the site in Chrome and give permission, and then:

```rb
@subscription = Subscription.last
Webpush.payload_send(endpoint: @subscription.endpoint, message: "tag|title|body", p256dh: @subscription.p256dh, auth: @subscription.auth, vapid: { subject: "mailto:" + ENV['VAPID_CONTACT_EMAIL'], public_key: ENV['VAPID_PUBLIC_KEY'] , private_key: ENV['VAPID_PRIVATE_KEY'] }, ttl: 60 * 60)
```
