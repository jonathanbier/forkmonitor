import React from 'react';

import {
    Badge
} from 'reactstrap';

class NodeStatus extends React.Component {
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
      <span> {badge}</span>
    )
  }
}
export default NodeStatus
