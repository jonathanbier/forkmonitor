import React from 'react';

import Moment from 'react-moment';

import {
    Badge,
    BreadcrumbItem,
    Breadcrumb
} from 'reactstrap';

import NodeName from './nodeName';

class Node extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      node: props.node
    };
  }

  render() {
    return(
      <li>
        <b>
          <NodeName node={this.state.node} />
          {this.state.node.unreachable_since!=null &&
            <span> <Badge color="warning">Offline</Badge></span>
          }
          {this.state.node.ibd &&
            <span> <Badge color="info">Syncing</Badge></span>
          }
        </b>
      </li>
    )
  }
}
export default Node
