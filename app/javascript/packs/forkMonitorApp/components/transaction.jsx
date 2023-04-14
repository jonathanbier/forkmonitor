import React from 'react';
import PropTypes from 'prop-types';

import Moment from 'react-moment';

import Explorer from './explorer';

class Transaction extends React.Component {
  render() {
    return(
      <tr>
        <td>
          <Explorer blockstream coin={ this.props.coin } tx={ this.props.tx_id }/>&nbsp;
          <Explorer btcCom coin={ this.props.coin } tx={ this.props.tx_id }/>&nbsp;
        </td>
        { this.props.fee_rate != null &&
          <td>
            { this.props.fee_rate }
          </td>
        }
        <td>
          { this.props.tx_id }
        </td>
      </tr>
    );
  }
}

Transaction.propTypes = {
  tx_id: PropTypes.string.isRequired,
  fee_rate: PropTypes.number
}

export default Transaction
