import React from 'react';

import Moment from 'react-moment';

import {
    BreadcrumbItem,
    Breadcrumb
} from 'reactstrap';

import NodeName from './nodeName';
import NodeInfo from './nodeInfo';
import NodeBehind from './nodeBehind';
import NodeBehindBlocks from './nodeBehindBlocks';
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
      </tr>
    )
  }
}
export default Node
