# Fork Monitor [![Build Status](https://travis-ci.org/BitMEXResearch/forkmonitor.svg?branch=master)](https://travis-ci.org/BitMEXResearch/forkmonitor)

## Development

Install Ruby 2.5.3 through a version manager such as [RVM](https://rvm.io). Install
the bundler and foreman gems, then run bundler:

```
gem install bundler foreman
bundle install --without production
```

To check if nodes are reachable:

```
rake debug:node_info
```

Run the server:

```
foreman start -f Procfile.dev -p 3000
```

To manually query a node:

```
rails c
info = BitcoinClient.nodes[0].getblockchaininfo
info["blocks"]
=> 548121
```

To get the list of RPC commands and execute an arbitrary command:

```
puts BitcoinClient.nodes[0].help
BitcoinClient.nodes[0].client.request("getblock", )
```
