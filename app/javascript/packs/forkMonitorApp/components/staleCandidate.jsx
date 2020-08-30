import React from 'react';
import Moment from 'react-moment';

import Explorer from './explorer';

class StaleCandidate extends React.Component {
  render() {
    return(
      <tr>
        <td>{ this.props.length <= 100 ? this.props.length : "100+" }</td>
        <td>{ this.props.root.hash }</td>
        <td>
          <Moment format="YYYY-MM-DD HH:mm:ss" tz="UTC" parse="X">{ this.props.root.timestamp }</Moment>
        </td>
        <td>{ this.props.root.pool }</td>
        <td>
          <Explorer blockstream block={ this.props.root.hash }/>&nbsp;
          <Explorer btcCom block={ this.props.root.hash }/>
        </td>
        <td>
          <Explorer blockstream block={ this.props.tip.hash }/>&nbsp;
          <Explorer btcCom block={ this.props.tip.hash }/>
        </td>
      </tr>
    )
  }
}
export default StaleCandidate
