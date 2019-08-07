import React from 'react';

import Moment from 'react-moment';

import {
    Badge,
    BreadcrumbItem,
    Breadcrumb
} from 'reactstrap';

import NodeName from './nodeName';
import NodeInfo from './nodeInfo';
import NodeBehind from './nodeBehind';
import NodeBehindBlocks from './nodeBehindBlocks';

class Node extends React.Component {
  render() {
    let badge;
    if (this.props.node.unreachable_since != null) {
      badge = <Badge color="warning">Offline</Badge>;
    } else if ( this.props.node.ibd  ) {
      badge = <Badge color="info">Syncing</Badge>;
    } else {
      badge = <Badge color="success">Online</Badge>;
    }
    return(
      <tr>
        <td>
          <NodeBehindBlocks chaintip={ this.props.chaintip } node={ this.props.node }/>
          <NodeName node={this.props.node} />
          <NodeInfo chaintip={ this.props.chaintip } node={this.props.node} />
          <span> {badge}</span>
          <NodeBehind chaintip={ this.props.chaintip } node={ this.props.node } min={ 2 } />
        </td>
      </tr>
    )
  }
}
export default Node
