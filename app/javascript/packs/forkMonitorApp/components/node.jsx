import React from 'react';

import PropTypes from 'prop-types';

import Moment from 'react-moment';
import 'moment-timezone';

import {
    BreadcrumbItem,
    Breadcrumb
} from 'reactstrap';

import NodeName from './nodeName';
import NodeInfo from './nodeInfo';
import NodeBehind from './nodeBehind';
import NodeBehindBlocks from './nodeBehindBlocks';
import NodeInflation from './nodeInflation';
import NodeStatusBadge from './nodeStatusBadge';

class Node extends React.Component {
  render() {
    return(
      <tr>
        <td>
          <NodeBehindBlocks chaintip={ this.props.chaintip } node={ this.props.node }/>
          <NodeName node={this.props.node} />
          { this.props.node.link &&
            <span> <a href={ this.props.node.link } target="_blank">
              { this.props.node.link_text }
            </a></span>
          }
          <NodeInfo chaintip={ this.props.chaintip } node={this.props.node} />
          <NodeStatusBadge node={this.props.node} />
          <NodeBehind chaintip={ this.props.chaintip } node={ this.props.node } />
        </td>
        <td align="right">
          { this.props.chaintip && this.props.chaintip.block && this.props.node.block_first_seen_at &&
            (() => {
              const times = this.props.chaintip.nodes
                .map(n => n.block_first_seen_at)
                .filter(Boolean)
                .map(t => new Date(t).getTime());
              const minTime = Math.min(...times);
              const maxTime = Math.max(...times);
              const myTime = new Date(this.props.node.block_first_seen_at).getTime();
              let color = 'black';
              if (times.length > 1) {
                if (myTime === minTime) color = 'green';
                else if (myTime === maxTime) color = 'red';
              }
              return (
                <span style={{ color }}>
                  First seen: <Moment format="HH:mm:ss" tz="UTC">{ this.props.node.block_first_seen_at }</Moment> UTC
                </span>
              );
            })()
          }
          { this.props.node.has_mirror_node &&
            <NodeInflation
              node={ this.props.node }
              txOutset={ this.props.node.tx_outset }
              lastTxOutset={ this.props.node.last_tx_outset }
              cableApp={ this.props.cableApp }
            />
          }
        </td>
      </tr>
    )
  }
}

Node.propTypes = {
  cableApp: PropTypes.any.isRequired
}

export default Node
