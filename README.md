# Fork Monitor

## Development

Install Ruby 2.5.3 through a version manager such as [RVM](https://rvm.io). Install
the bundler and foreman gems, then run bundler:

```
gem install bundler foreman
bundle install --without production
```

Create a file `.env` and add node connection info:

```
NODE_1=BTC:host:port|username|password|name|height
NODE_2=...
...
```

The optional `height` fields indicates a common ancestor, used to calculate proof-of-work since a fork. 

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
