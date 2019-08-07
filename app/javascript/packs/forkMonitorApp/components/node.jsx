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
          <NodeName node={this.props.node} />
          <NodeInfo node={this.props.node} />
          <span> {badge}</span>
          <NodeBehind chaintip={ this.props.chaintip } node={ this.props.node }/>
        </td>
      </tr>
    )
  }
}
export default Node
