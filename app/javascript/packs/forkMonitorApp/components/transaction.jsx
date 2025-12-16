import React from 'react';
import PropTypes from 'prop-types';

import Moment from 'react-moment';

import Explorer from './explorer';

class Transaction extends React.Component {
  render() {
    return(
      <tr>
        <td>
          <Explorer mempool coin={ this.props.coin } tx={ this.props.tx_id }/>
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
