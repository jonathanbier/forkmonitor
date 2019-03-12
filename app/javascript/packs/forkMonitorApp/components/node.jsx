import React from 'react';

import Moment from 'react-moment';

import {
    Badge,
    BreadcrumbItem,
    Breadcrumb
} from 'reactstrap';

import NodeName from './nodeName';

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
      <li>
        <b>
          <NodeName node={this.props.node} />
          <span> {badge}</span>
        </b>
      </li>
    )
  }
}
export default Node
