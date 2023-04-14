import React from 'react';

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faRss } from '@fortawesome/free-solid-svg-icons'


class RSSFeeds extends React.Component {
  render() {
    return(
      <div>
        <h2>RSS Feeds</h2>

        <p>You can setup notifications for the RSS feeds below using a service like <a href="https://ifttt.com">IFTTT</a>.</p>

        <ul>
          <li>
          <a href="/feeds/btc/blocks/invalid.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a>&nbsp;
            <b>Invalid Blocks</b>
            <p>
              Fork Monitor stores all invalid chaintip blocks in its own database. Invalid
              blocks are occasionally found and don't have to be a problem (except
              for the miner), as long as all nodes agree they're invalid.
            </p>
          </li>
          <li>
            <a href="/feeds/invalid_blocks/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a>&nbsp;
            <b>Inconsistent validity (blocks)</b>
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
          </li>
          <li>
            <a href="/feeds/inflated_blocks/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a>&nbsp;
            <b>Inflated Blocks</b>
            <p>
              Creates an alert if a block increases the total supply by more than 12.5 (later: 6.25, etc) BTC.
              This is checked using `gettxoutsetinfo`.
            </p>
          </li>
          <li>
            <a href="/feeds/stale_candidates/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a>&nbsp;
            <b>Stale block candidates</b>
            <p>
              Creates an alert if there is more than one block at the tip height of the chain.
              E.g. if there are two blocks at height N then one is expected to become stale.

              This will not create an alert for all stale blocks, only those that have been
              processed by our nodes.
            </p>
          </li>
          <li>
            <a href="/feeds/blocks/unknown_pools/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a>&nbsp;
            <b>Unidentified mining pools</b>
            <p>
              List of recent blocks mined by a pool that can't be matched <a href="https://github.com/BitMEXResearch/forkmonitor/blob/master/app/models/block.rb#L158">by this list</a>
              </p>
          </li>
          <li>
            <a href="/feeds/version_bits.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a>&nbsp;
            <b>Version bits signalling</b>
            <p>
              Version bits flagged in the past 100 blocks (currently uses 10 as lower threshold).
            </p>
          </li>
          <li>
            <a href="/feeds/lagging_nodes.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a>&nbsp;
            <b>Unreachable nodes</b>
            <p>
              Checks if any of the nodes fell behind. This doesn't have to be
              a consensus problem, but we filter common reasons like being offline,
              in initial block download or not having peers.
            </p>
          </li>
          <li>
            <a href="/feeds/nodes/unreachable.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a>&nbsp;
            <b>Unreachable nodes</b>
            <p>This includes mirror nodes, which are used for inflation checks.</p>
          </li>
          <li>
            <b>Lightning transactions</b>
            <p>
              See <a href="https://blog.bitmex.com/lightning-network-justice/">Lightning Network (Part 3) – Where Is The Justice?</a> for background.
            </p>
            <ul>
              <li>
                <a href="/feeds/ln_penalties/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a>&nbsp;
                <b>Penalties</b>
              </li>
              <li>
                <a href="/feeds/ln_sweeps/btc.rss" target="_blank"><FontAwesomeIcon icon={faRss} /></a>&nbsp;
                <b>Delayed sweeps</b>
              </li>
            </ul>
          </li>
        </ul>
      </div>
    )
  }
}

export default RSSFeeds
