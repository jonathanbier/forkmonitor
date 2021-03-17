import React from 'react';

import Moment from 'react-moment';
import 'moment-timezone'
import NumberFormat from 'react-number-format';

import PropTypes from 'prop-types';
import { Link } from "react-router-dom";

import {
} from 'reactstrap';

class BlockInfo extends React.Component {
  render() {
    return(
      <p className="block-info">
        Height: <NumberFormat value={ this.props.block.height } displayType={'text'} thousandSeparator={true} />
        <br/>
        Miner timestamp: <Moment format="YYYY-MM-DD HH:mm:ss" tz="UTC" parse="X">{this.props.block.timestamp}</Moment> UTC
        <br/>
        First seen: <Moment format="HH:mm:ss" tz="UTC">{this.props.block.created_at}</Moment> UTC
        <br/>
        { this.props.block.pool &&
          <span>
            Mined by: { this.props.block.pool }
            <br/>
          </span>
        }
        Accumulated log2(PoW): <NumberFormat value={this.props.block.work} displayType={'text'} decimalScale={6} fixedDecimalScale={true} />
        { this.props.block.size &&
            <span><br />Size: <NumberFormat value={ this.props.block.size / 1000000 } displayType={'text'} thousandSeparator={true} decimalScale={2} fixedDecimalScale={true} /> MB</span>
        }
        <br />
        { this.props.block.tx_count != null &&
          <span>
            Transaction count: <NumberFormat value={ this.props.block.tx_count } displayType={'text'} thousandSeparator={true} />
          </span>
        }
        <br />
        {
          this.props.block.total_fee != null &&
          <span>
            Fees: <NumberFormat value={ this.props.block.total_fee } displayType={'text'} decimalScale={8} fixedDecimalScale={true} /> BTC
          </span>
        }
        <br />
        { this.props.link &&
          <Link to={ `/blocks/${ this.props.block.coin }/${ this.props.block.hash }` }>More info...</Link>
        }
      </p>
    )
  }
}

BlockInfo.propTypes = {
  link: PropTypes.bool
}

BlockInfo.defaultProps = {
  link: false
}

export default BlockInfo
