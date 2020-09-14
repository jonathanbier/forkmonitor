import React from 'react';

import Moment from 'react-moment';
import 'moment-timezone'
import NumberFormat from 'react-number-format';

import {
} from 'reactstrap';

class Chaintip extends React.Component {
  render() {
    return(
      <p className="chaintip-info">
        Height: <NumberFormat value={ this.props.chaintip.block.height } displayType={'text'} thousandSeparator={true} /> (<Moment format="YYYY-MM-DD HH:mm:ss" tz="UTC" parse="X">{this.props.chaintip.block.timestamp}</Moment> UTC)
        <br/>
        { this.props.chaintip.block.pool &&
          <span>
            Mined by: { this.props.chaintip.block.pool }
            <br/>
          </span>
        }
        Accumulated log2(PoW): <NumberFormat value={this.props.chaintip.block.work} displayType={'text'} decimalScale={6} fixedDecimalScale={true} />
        { this.props.chaintip.block.size &&
            <span><br />Size: <NumberFormat value={ this.props.chaintip.block.size / 1000000 } displayType={'text'} thousandSeparator={true} decimalScale={2} fixedDecimalScale={true} /> MB</span>
        }
        <br />
        Transaction count: <NumberFormat value={ this.props.chaintip.block.tx_count } displayType={'text'} thousandSeparator={true} />
      </p>
    )
  }
}
export default Chaintip
