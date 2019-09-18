import React from 'react';

import {
    UncontrolledAlert
} from 'reactstrap';

import NodeName from './nodeName';

class AlertInvalid extends React.Component {
  render() {
    return(
      <UncontrolledAlert color="danger">
        <NodeName node={this.props.invalidBlock.node} /> considers
        block { this.props.invalidBlock.block.hash } at height { this.props.invalidBlock.block.height } invalid.
        This block was mined by { this.props.invalidBlock.block.pool ? this.props.invalidBlock.block.pool : "an unknown pool" }.
        { this.props.invalidBlock.block.first_seen_by &&
          <span>
            {} It was first seen and accepted as valid by <NodeName node={this.props.invalidBlock.block.first_seen_by} />.
          </span>
        }
      </UncontrolledAlert>
    );
  }
}
export default AlertInvalid
