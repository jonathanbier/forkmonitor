import React from 'react';
import Moment from 'react-moment';

import Explorer from './explorer';

class StaleCandidate extends React.Component {
  render() {
    return(
      <tr>
        <td>{ this.props.block.hash }</td>
        <td>
          <Moment format="YYYY-MM-DD HH:mm:ss" tz="UTC" parse="X">{ this.props.block.timestamp }</Moment>
        </td>
        <td>{ this.props.block.pool }</td>
        <td>
          <Explorer blockstream block={ this.props.block.hash }/>&nbsp;
          <Explorer btcCom block={ this.props.block.hash }/>
        </td>
      </tr>
    )
  }
}
export default StaleCandidate
