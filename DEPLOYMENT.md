# Forkmonitor.info deployment

The production site [forkmonitor.info](https://forkmonitor.info) is deployed on a Ubuntu 20.04 server with 8 CPUs and 16 GB RAM (10 GB swap). This machine also runs a two mainnet nodes (usually the most recent version of Bitcoin Core and its mirror).

## Bitcoin nodes

Ensure the most recent (patched) node with a mirror supports `getblockfrompeer`.
See find_missing in block.rb

## Users

In addition to root user, there is a `bitcoin` and a `forkmonitor` user which don't have `sudo` rights.

## Nginx configuration

Site config: [/etc/nginx/sites-available/forkmonitor](deploy/etc/nginx/sites-available/forkmonitor)

## Certbot

See Certbot tutorial and the nginx config file above. In the forkmonitor home
directy, run `openssl dhparam -out dhparams.pem 2048`

Certbot automatically creates a renewal cron, probably in /etc/cron.d/certbot.

Configure it restart nginx after a renewal, or users will see an https error. Add
the following line to /etc/letsencrypt/cli.ini:

```
deploy-hook = systemctl reload nginx
```

See also: https://blog.arnonerba.com/2019/01/lets-encrypt-how-to-automatically-restart-nginx-with-certbot

## Mining pools

In `shared/vendor` do:

```
git clone https://github.com/bitcoin-data/mining-pools.git
cd mining-pools
python contrib/create-old-pools-json.py pools.json
```

## Capistrano and rbenv

The site is deployed using Capistrano:

```
cap production deploy
```

On the server, ruby is installed using rbenv. Env vars are set in [.rbenv-vars](deploy/home/forkmonitor/forkmonitor/.rbenv-vars).

## Cron and rake

In order for cron jobs to run rake tasks and play nicely with rbenv, it's a bit clunky.
See rake.sh in home directory.

User `crontab`:
```
# MAILTO=...
# m h  dom mon dow   command
* * * * * /usr/bin/flock -n /tmp/pollBTC.lock /usr/bin/cronic ~/rake.sh nodes:poll_repeat[BTC]
* * * * * /usr/bin/flock -n /tmp/pollTBTC.lock /usr/bin/cronic ~/rake.sh nodes:poll_repeat[TBTC]
# * * * * * /usr/bin/flock -n /tmp/pollBTC_stale.lock /usr/bin/cronic ~/rake.sh nodes:poll_unless_fresh[BTC]
* * * * * /usr/bin/flock -n /tmp/heavyTBTC.lock /usr/bin/cronic ~/rake.sh nodes:heavy_checks_repeat[TBTC]
* * * * * /usr/bin/flock -n /tmp/heavyBTC.lock /usr/bin/cronic ~/rake.sh nodes:heavy_checks_repeat[BTC]
* * * * * /usr/bin/flock -n /tmp/rollbackBTC.lock /usr/bin/cronic ~/rake.sh nodes:rollback_checks_repeat[BTC]
* * * * * /usr/bin/flock -n /tmp/rollbackTBTC.lock /usr/bin/cronic ~/rake.sh nodes:rollback_checks_repeat[TBTC]
* * * * * /usr/bin/flock -n /tmp/blockTemplate.lock /usr/bin/cronic ~/rake.sh nodes:getblocktemplate_repeat[BTC]
0 0 * * * ~/rake.sh pools:fetch
```

`poll_unless_fresh` is currently unused; it's only needed for Libbitcoin.

## Tor configuration

Roughly follows the tutorial [here](https://chown.io/guide-host-your-own-onion-site-tor-nginx/). Suggestions to improve our [/etc/tor/torrc](deploy/etc/tor/torrc) are welcome.

## Bitcoin nodes

These are run using systemd, mostly based on the Bitcoin Core [bitcoind.service example](https://github.com/bitcoin/bitcoin/blob/master/contrib/init/bitcoind.service). It uses the configuration in `/home/bitcoin/.bitcoin/bitcoin.conf`. `bitcoind-mirror.service` follows the same pattern.

For the mirror nodes, use `-datadir=/home/bitcoin/.bitcoin2`.

Installing / updating Bitcoin Core is a matter of stopping these services and then: `sudo tar -xzvf bitcoin-0.21.1-x86_64-linux-gnu.tar.gz -C /usr/local --strip 1`

### Patches

Currently the Bitcoin Core v0.21.0 mirror node is patched: https://github.com/BitMEXResearch/bitcoin/pull/1

To run a patched node instead, install [dependencies](https://github.com/bitcoin/bitcoin/blob/master/doc/build-unix.md#linux-distribution-specific-instructions), clone the source in `/home/bitcoin/src` and compile locally:

```
git clone https://github.com/bitcoin/bitcoin.git
cd bitcoin
git remote add BitMEXResearch https://github.com/BitMEXResearch/bitcoin.git
git checkout v0.21.0-patched
./autogen.sh
./configure --with-miniupnpc=no --disable-bench --disable-tests --without-gui --disable-wallet --disable-zmq --prefix=/home/bitcoin
make -j5
make install
```

In the systemd service file, change `ExecStart=` to `/home/bitcoin/bin/bitcoind`.

## Log files

To keep the log files from spiraling out of control, see [/etc/logrotate.conf](deploy/etc/logrotate.conf).

## Backups

As the `forkmonitor` user:

```
pg_dump -U forkmonitor forkmonitor > forkmonitor.dump
```

As the root:

```
sudo -s
tar -czvf backup.tar.gz /var/lib/tor/nginx/* /etc/tor/torrc /etc/nginx/sites-enabled/* /etc/systemd/system/bitcoind* /home/forkmonitor/forkmonitor/.rbenv-vars /var/spool/cron/crontabs/forkmonitor /etc/letsencrypt/live/www.forkmonitor.info /etc/logrotate.conf /home/forkmonitor/forkmonitor.dump
```

And then copy the result via SSH:

```
scp ...@forkmonitor:backup.tar.gz backup_`date +"%Y-%m-%d_%H.%M.%S"`.tar.gz
```
