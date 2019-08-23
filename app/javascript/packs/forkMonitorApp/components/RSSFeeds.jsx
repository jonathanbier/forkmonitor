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
          <li>BTC <a href="/feeds/invalid_blocks/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BCH <a href="/feeds/invalid_blocks/bch.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BSV <a href="/feeds/invalid_blocks/bsv.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

        <p>
          Fork Monitor stores all valid blocks in its own database, including
          intermediate blocks between poll moments, and including `valid-fork`
          entries from `getchaintips`. It then takes the `invalid` chaintip entries
          from each node and checks if it knows that block. If so then it sends
          out an alert.
        </p>

        <h3>Stale block candidates</h3>

        <ul>
          <li>BTC <a href="/feeds/stale_candidates/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BCH <a href="/feeds/stale_candidates/bch.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
          <li>BSV <a href="/feeds/stale_candidates/bsv.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
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

        <h3>Lagging test nodes</h3>

        <ul>
          <li>BTC <a href="/feeds/lagging_nodes.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a></li>
        </ul>

        <p>
          Checks if any of the test nodes fell behind. This doesn't have to be
          a consensus problem,but we filter common reasons like being offline,
          in initial block download or not having peers.
        </p>
      </div>
    )
  }
}

export default RSSFeeds
