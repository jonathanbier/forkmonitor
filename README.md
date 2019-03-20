# Fork Monitor [![Build Status](https://travis-ci.org/BitMEXResearch/forkmonitor.svg?branch=master)](https://travis-ci.org/BitMEXResearch/forkmonitor) [![Coverage Status](https://coveralls.io/repos/github/BitMEXResearch/forkmonitor/badge.svg?branch=master)](https://coveralls.io/github/BitMEXResearch/forkmonitor?branch=master)

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
