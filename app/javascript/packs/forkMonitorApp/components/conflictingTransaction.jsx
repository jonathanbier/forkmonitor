import React from 'react';
import PropTypes from 'prop-types';

import Moment from 'react-moment';

import Explorer from './explorer';

class ConflictingTransaction extends React.Component {
  render() {
    return(
      <tr>
        <td>
          { this.props.tx.amount }
        </td>
        <td>
          <Explorer blockstream tx={ this.props.tx.tx_id }/>&nbsp;
          <Explorer btcCom tx={ this.props.tx.tx_id }/>&nbsp;
          { this.props.tx.tx_id }
        </td>
        <td>
          <Explorer blockstream tx={ this.props.conflict.tx_id }/>&nbsp;
          <Explorer btcCom tx={ this.props.conflict.tx_id }/>&nbsp;
          { this.props.conflict.tx_id }
        </td>
      </tr>
    );
  }
}

export default ConflictingTransaction
