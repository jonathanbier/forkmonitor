import React from 'react';

import {
    UncontrolledAlert
} from 'reactstrap';

import NodeName from './nodeName';

class AlertInflation extends React.Component {
  render() {
    return(
      <UncontrolledAlert color="danger">
        <NodeName node={this.props.inflatedBlock.node} /> detected inflation in
        block { this.props.inflatedBlock.block.hash } at height { this.props.inflatedBlock.block.height }.
        This block was mined by { this.props.inflatedBlock.block.pool ? this.props.inflatedBlock.block.pool : "an unknown pool" }.
        { this.props.inflatedBlock.block.first_seen_by &&
          <span>
            {} It was first seen and accepted as valid by <NodeName node={this.props.inflatedBlock.block.first_seen_by} />.
          </span>
        }
      </UncontrolledAlert>
    );
  }
}
export default AlertInflation
