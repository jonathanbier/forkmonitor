## Local server and console

Install ZeroMQ (for Libbitcoin), e.g. on macOS: `brew install zeromq`

Install Postgres, e.g. on macOS: `brew install postgresql`

Install Redis, e.g. on macOS: `brew install redis` and see [instructions](https://redis.io/docs/latest/operate/oss_and_stack/install/install-redis/install-redis-on-mac-os/).

To use Rails cache, install memcacher, e.g. on macOS: `brew install memcached`. To toggle cache, use `rails dev:cache`

Install Python. When using pyenv, use `env PYTHON_CONFIGURE_OPTS='--enable-shared' pyenv install VERSION` in order for [PyCall](https://github.com/mrkn/pycall.rb) to work.

Install Ruby 3.1.4 through a version manager such as [RVM](https://rvm.io) or [rbenv](https://github.com/rbenv/rbenv). Install
the bundler and foreman gems, then run bundler:

```
gem install bundler foreman
bundle config set --local without 'production'
bundle install
```

You also need [Yarn](https://yarnpkg.com/lang/en/docs/install/#mac-stable), a
package manager for NodeJS. Once installed, run:

```sh
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

In order to log in to /admin and add nodes, you need to create an admin user:

On Apple Silicon you may need to set `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`
in order to make RPC calls (e.g. when adding a node). Or use `rails console`.

```
rails console

User.create(email: "you@example.com", password: "1234", confirmed_at: Time.now)
```

To check if nodes are reachable:

```
rake debug:node_info
```

To poll nodes:

```
rake nodes:poll
```

Prefix rake command with `debug` or `info` to see more progress details:

```
rake debug nodes:poll
```

To poll all nodes continuously

```sh
rake nodes:poll_repeat
```

To check inflation, you need to run a mirror node and add it in the admin panel.

```
rake debug blocks:check_inflation
```

To run inflation checks continuously:

```
rake debug nodes:rollback_checks_repeat
```

The other long running heavy work tasks:

```
rake debug nodes:heavy_checks_repeat
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
Node.where.not(mirror_rpchost: nil).first.mirror_client.getchaintips
```

## Test suite

When switching between a binary and custom Bitcoin Core branch, comment
the `binary` and `binary_cli` lines in `util.py`, update `travis.yml`
and update the commit hash in `bitcoind.sh`.

Currently the tests use a downloaded binary and don't require a custom compiled version of Bitcoin Core.

### Custom Bitcoin Core branch


```sh
TRAVIS_BUILD_DIR=$PWD ./bitcoind.sh
```

Edit `bitcoin/test/config.ini` and replace `$TRAVIS_BUILD_DIR` with the root path
of this project.

To run Rails tests and monitor for changes:

```sh
guard
<hit enter>
```

### Bitcoin Core binary

Some of the tests require (a specific version of) Bitcoin Core. To install:

```
cd vendor/bitcoin
cp ../bitcoin-config.ini test/config.ini
test/get_previous_releases.py -b -t .. v23.0
```

On macOS you need to codesign the binaries (before v29):

```
codesign -s - vendor/v23.0/bin/bitcoin*
```

## Specs

To debug a test, use:

```sh
LOG_LEVEL=info rspec spec/models/block_spec.rb
```

To run Rails tests in parallel (optionally set `PARALLEL_TEST_PROCESSORS`):

```sh
rake parallel:create
rake parallel:prepare
rake parallel:spec
```

## Javascript tests

To run Javascript tests and monitor for changes:

```sh
yarn test --watch
```

## Test all the things and deploy

```
rubocop && yarn test && rake parallel:spec && git push && cap production deploy
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
WebPush.payload_send(endpoint: @subscription.endpoint, message: "tag|title|body", p256dh: @subscription.p256dh, auth: @subscription.auth, vapid: { subject: "mailto:" + ENV.fetch('VAPID_CONTACT_EMAIL'), public_key: ENV.fetch('VAPID_PUBLIC_KEY') , private_key: ENV.fetch('VAPID_PRIVATE_KEY') }, ttl: 60 * 60)
```
