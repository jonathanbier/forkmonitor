## Local server and console

Install ZeroMQ (for Libbitcoin), e.g. on macOS: `brew install zeromq`

Install Postgres, e.g. on macOS: `brew install postgresql`

Install Redis, e.g. on macOS: `brew install redis` and see [instructions](https://redis.io/docs/latest/operate/oss_and_stack/install/install-redis/install-redis-on-mac-os/).

To use Rails cache, install memcacher, e.g. on macOS: `brew install memcached`. To toggle cache, use `rails dev:cache`

Install Python. When using pyenv, use `env PYTHON_CONFIGURE_OPTS='--enable-shared' pyenv install VERSION` in order for [PyCall](https://github.com/mrkn/pycall.rb) to work.

Install Ruby 3.4.7 through a version manager such as [RVM](https://rvm.io) or [rbenv](https://github.com/rbenv/rbenv). Install
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
The tests use a downloaded Bitcoin Core binary and don't require a custom compiled version.

### Bitcoin Core binary

Some of the tests require (a specific version of) Bitcoin Core. To install:

```
cd vendor/bitcoin
cp ../bitcoin-config.ini test/config.ini
test/get_previous_releases.py -t .. v28.2
```

Upgrade node: `chaintip_spec.rb` relies on `vbparams` to maniuplate when
taproot is active. If `taproot` is removed from there, the test will no
longer work. As of v30 that's not the case yet. See:
https://github.com/bitcoin/bitcoin/pull/26201

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

## Continuous Integration

You can exercise the GitHub Actions workflow locally with [`act`](https://github.com/nektos/act). The repository expects Ruby to run in Docker, so map your CPU and optional caches explicitly:

```sh
cd forkmonitor
CPUS=$(( $(sysctl -n hw.ncpu) - 1 ))
CACHE_ROOT="$HOME/.cache/forkmonitor"
mkdir -p "$CACHE_ROOT"
BASE=(act -P ubuntu-latest=catthehacker/ubuntu:act-latest --container-architecture linux/amd64 --container-options "--cpus=${CPUS}" --env ACT=true --env COVERALLS_DISABLE=1 --env FM_CACHE_ROOT=/github/workspace/.cache/forkmonitor)

# RuboCop job
"${BASE[@]}" --job rubocop

# Rails spec suite (bind-mount a cached Bitcoin Core binary to skip downloads)
"${BASE[@]}" --bind "$CACHE_ROOT:/github/workspace/.cache/forkmonitor" --job server

# Client (Jest) job
"${BASE[@]}" --job client
```

Populate `vendor/v28.2` with the native binaries required by your host using the Bitcoin Core instructions above. The workflow points the container at `/github/workspace/.cache/forkmonitor`, so the first act run downloads Linux `amd64` releases into `~/.cache/forkmonitor/v28.2` and reuses them on subsequent runs without modifying your host-specific `vendor/v28.2` directory.

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
