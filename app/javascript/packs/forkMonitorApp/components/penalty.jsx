import React from 'react';

import Moment from 'react-moment';
import 'moment-timezone'
import NumberFormat from 'react-number-format';

class Penalty extends React.Component {
  render() {
    return(
      <tr className="pullLeft" >
        <td>
          <Moment format="YYYY-MM-DD HH:mm:ss" tz="UTC" parse="X">{this.props.penalty.block.timestamp}</Moment> UTC
        </td>
        <td>
          <NumberFormat value={ this.props.penalty.block.height } displayType={'text'} thousandSeparator={true} />
        </td>
        <td>
          { this.props.penalty.amount &&
            <span>
              <NumberFormat value={ this.props.penalty.amount } displayType={'text'} decimalScale={4} fixedDecimalScale={true} />
            </span>
          }
        </td>
        <td>
          <a href={"https://blockstream.info/tx/" + this.props.penalty.opening_tx_id} target="_blank">Opening</a>
        </td>
        <td>
          <span className="lightning-tx">
            <a href={"https://blockstream.info/tx/" + this.props.penalty.tx_id} target="_blank">{ this.props.penalty.tx_id }</a>
          </span>
        </td>
      </tr>
    );
  }
}
export default Penalty
