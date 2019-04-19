# Fork Monitor [![Build Status](https://travis-ci.org/BitMEXResearch/forkmonitor.svg?branch=master)](https://travis-ci.org/BitMEXResearch/forkmonitor) [![Coverage Status](https://coveralls.io/repos/github/BitMEXResearch/forkmonitor/badge.svg?branch=master)](https://coveralls.io/github/BitMEXResearch/forkmonitor?branch=master)

## RSS feeds

### Invalid Blocks

https://forkmonitor.info/feeds/invalid_blocks.rss

Fork Monitor stores all valid blocks in its own database, including intermediate blocks between poll moments, and including `valid-fork` entries from `getchaintips`. It then takes the `invalid` chaintip entries from each node and checks if it knows that block. If so then it sends out an alert.

### Orphan block candidates

https://forkmonitor.info/feeds/orphan_candidates.rss

Creates an alert if there is more than one block at the tip height of the chain.
E.g. if there are two blocks at height N then one is expected to get orphaned.

This will not create an alert for all orphan blocks, only those that have been
processed by our nodes.

### Version bit signaling

https://forkmonitor.info/feeds/version_bits.rss

Version bits flagged in the past 100 blocks (currently uses 10 as lower threshold).

### Lagging test nodes

https://forkmonitor.info/feeds/lagging_nodes.rss

Checks if any of the test nodes fell behind. This doesn't have to be a consensus problem, but we filter common reasons like being offline, in initial block download or not having peers.

## Development

Install Ruby 2.5.3 through a version manager such as [RVM](https://rvm.io). Install
the bundler and foreman gems, then run bundler:

```
gem install bundler foreman
bundle install --without production:test_pg
```

You also need [Yarn](https://yarnpkg.com/lang/en/docs/install/#mac-stable), a package
manager for NodeJS. Once installed, run:

```
yarn
```

Now run the server (this can take a while the first time, as well as each time you modify javascript):

```
foreman start -f Procfile.dev -p 3000
```

To check if nodes are reachable:

```
rake debug:node_info
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

To run Rails tests and monitor for changes:

```sh
guard
<hit enter>
```

To run Javascript tests and monitor for changes:

```sh
yarn test --watch
```

## Postgres

By default development and test environments use SQlite3. In order to develop and
test with Postgres, use the test_pg and development_pg environments instead.

```sh
bundle install --with test_pg:development_pg
RAILS_ENV=test_pg rake db:migrate
RAILS_ENV=development_pg rake db:migrate
RAILS_ENV=test_pg rspec
RAILS_ENV=development_pg rails server
```
