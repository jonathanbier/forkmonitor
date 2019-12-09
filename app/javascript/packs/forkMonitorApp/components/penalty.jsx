import React from 'react';

import Moment from 'react-moment';
import 'moment-timezone'
import NumberFormat from 'react-number-format';

class Penalty extends React.Component {
  render() {
    return(
      <span>
        <Moment format="YYYY-MM-DD HH:mm:ss" tz="UTC" parse="X">{this.props.penalty.block.timestamp}</Moment> UTC
        in block <NumberFormat value={ this.props.penalty.block.height } displayType={'text'} thousandSeparator={true} />:&nbsp;
        <small><a href={"https://blockstream.info/tx/" + this.props.penalty.tx_id} target="_blank">{ this.props.penalty.tx_id }</a></small>
      </span>
    );
  }
}
export default Penalty
