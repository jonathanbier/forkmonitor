import React from 'react';

import {
    UncontrolledAlert
} from 'reactstrap';

import NumberFormat from 'react-number-format';

import NodeName from './nodeName';

class AlertInflation extends React.Component {
  render() {
    const height = this.props.inflatedBlock.block.height;
    const comparison_height = this.props.inflatedBlock.comparison_block.height;
    const inflation = this.props.inflatedBlock.actual_inflation - this.props.inflatedBlock.max_inflation;
    return(
      <UncontrolledAlert color="danger">
        <NodeName node={this.props.inflatedBlock.node} /> detected <NumberFormat value={inflation} displayType={'text'} decimalScale={8} fixedDecimalScale={false} /> BTC extra inflation
        { (height - comparison_height > 1) &&
          <span> between blocks { this.props.inflatedBlock.comparison_block.hash } at height { comparison_height } and </span>
        }
        { (height - comparison_height == 1) &&
          <span> in block </span>
        }
        { this.props.inflatedBlock.block.hash } at height { height }.
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
