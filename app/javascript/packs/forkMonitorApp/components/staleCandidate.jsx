import React from 'react';

import Explorer from './explorer';

class StaleCandidate extends React.Component {
  render() {
    return(
      <tr>
        <td>{ this.props.block.hash }</td>
        <td>{ this.props.block.timestamp }</td>
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
