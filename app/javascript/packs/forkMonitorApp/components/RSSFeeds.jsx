import React from 'react';

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faRss } from '@fortawesome/free-solid-svg-icons'


class RSSFeeds extends React.Component {
  render() {
    return(
      <div>
        <h2>RSS Feeds</h2>

        <p>You can setup notifications for the RSS feeds below using a service like <a href="https://ifttt.com">IFTTT</a>.</p>

        <h3>Invalid Blocks</h3>

        <ul>
          <li>BTC <a href="/feeds/btc/blocks/invalid.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BTC testnet<a href="/feeds/tbtc/blocks/invalid.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BCH <a href="/feeds/bch/blocks/invalid.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

        <p>
          Fork Monitor stores all invalid chaintip blocks in its own database. Invalid
          blocks are occasionally found and don't have to be a problem (except
          for the miner), as long as all nodes agree they're invalid.
        </p>

        <h3>Inconsistent validity (blocks)</h3>

        <ul>
          <li>BTC <a href="/feeds/invalid_blocks/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BTC testnet <a href="/feeds/invalid_blocks/tbtc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BCH <a href="/feeds/invalid_blocks/bch.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

        <p>
          Invalid blocks are occasionally found and don't have to be a problem (except
          for the miner), as long as all nodes agree they're invalid. But when some
          nodes consider a block valid, while others consider it invalid, this
          inconsistent validity could indicate a consensus bug.
        </p>

        <p>
          Fork Monitor stores both valid and invalid blocks in its own database,
          including intermediate blocks between poll moments, and including `valid-fork`
          entries from `getchaintips`. It then takes the `invalid` chaintip entries
          from each node and checks if any other node considered it valid. If so
          then it sends out an alert.
        </p>

        <h3>Inflated Blocks</h3>

        <ul>
          <li>BTC <a href="/feeds/inflated_blocks/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BTC testnet <a href="/feeds/inflated_blocks/tbtc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

        <p>
          Creates an alert if a block increases the total supply by more than 12.5 (later: 6.25, etc) BTC.
          This is checked using `gettxoutsetinfo`.
        </p>

        <h3>Stale block candidates</h3>

        <ul>
          <li>BTC <a href="/feeds/stale_candidates/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BTC testnet <a href="/feeds/stale_candidates/tbtc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BCH <a href="/feeds/stale_candidates/bch.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

        <p>
          Creates an alert if there is more than one block at the tip height of the chain.
          E.g. if there are two blocks at height N then one is expected to become stale.

          This will not create an alert for all stale blocks, only those that have been
          processed by our nodes.
        </p>

        <h3>Version bit signaling</h3>

        <ul>
          <li>BTC <a href="/feeds/version_bits.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

        <p>Version bits flagged in the past 100 blocks (currently uses 10 as lower threshold).</p>

        <h3>Lagging nodes</h3>

        <ul>
          <li>BTC <a href="/feeds/lagging_nodes.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

        <h3>Unreachable nodes</h3>

        <ul>
          <li>All coins <a href="/feeds/nodes/unreachable.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

        <p>
          Checks if any of the nodes fell behind. This doesn't have to be
          a consensus problem, but we filter common reasons like being offline,
          in initial block download or not having peers.
        </p>

        <h3>Lightning transactions</h3>

        <p>
          See <a href="https://blog.bitmex.com/lightning-network-justice/">Lightning Network (Part 3) – Where Is The Justice?</a> for background.
        </p>

        <b>Penalties</b>

        <ul>
          <li>BTC <a href="/feeds/ln_penalties/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

        <b>Delayed sweeps</b>

        <ul>
          <li>BTC <a href="/feeds/ln_sweeps/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

      </div>
    )
  }
}

export default RSSFeeds
