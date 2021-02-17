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
        <td>
          { this.props.tx_id }
        </td>
      </tr>
    );
  }
}

export default Transaction
