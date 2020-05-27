import React from 'react';

import PropTypes from 'prop-types';

import Moment from 'react-moment';

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
          <NodeInfo chaintip={ this.props.chaintip } node={this.props.node} />
          <NodeStatusBadge node={this.props.node} />
          <NodeBehind chaintip={ this.props.chaintip } node={ this.props.node } />
        </td>
        <td align="right">
          { this.props.node.has_mirror_node &&
            <NodeInflation
              node={ this.props.node }
              txOutset={ this.props.node.tx_outset }
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
