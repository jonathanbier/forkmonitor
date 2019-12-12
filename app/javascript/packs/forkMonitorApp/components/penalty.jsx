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
              <NumberFormat value={ this.props.penalty.amount / 100000000.0 } displayType={'text'} decimalScale={4} fixedDecimalScale={true} />
            </span>
          }
        </td>
        <td>
          <a href={"https://blockstream.info/tx/" + this.props.penalty.opening_tx_id} target="_blank"><img src="https://blog.bitmex.com/wp-content/uploads/2019/12/blockstream.png" alt="Blockstream.info" width="16" height="16"></a>&nbsp;-&nbsp;
          <a href={"https://btc.com/" + this.props.penalty.opening_tx_id} target="_blank"><img src="https://blog.bitmex.com/wp-content/uploads/2019/12/btc.jpg" alt="BTC.com" width="16" height="16"></a>
        </td>
        <td>
          <span className="lightning-tx">
            <a href={"https://blockstream.info/tx/" + this.props.penalty.tx_id} target="_blank"><img src="https://blog.bitmex.com/wp-content/uploads/2019/12/blockstream.png" alt="Blockstream.info" width="16" height="16"></a>&nbsp;-&nbsp;
            <a href={"https://btc.com/" + this.props.penalty.tx_id} target="_blank"><img src="https://blog.bitmex.com/wp-content/uploads/2019/12/btc.jpg" alt="BTC.com" width="16" height="16"></a>
          </span>
        </td>
      </tr>
    );
  }
}
export default Penalty
