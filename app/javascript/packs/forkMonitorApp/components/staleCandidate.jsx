import React from 'react';
import Moment from 'react-moment';
import PropTypes from 'prop-types';

import Explorer from './explorer';

class StaleCandidate extends React.Component {
  render() {
    return(
      <tr>
        <td>{ this.props.length <= 100 ? this.props.length : "100+" }</td>
        <td>{ this.props.root.hash }</td>
        <td>
          { this.props.root.timestamp &&
            <Moment format="YYYY-MM-DD HH:mm:ss" tz="UTC" parse="X">{ this.props.root.timestamp }</Moment>
          }
        </td>
        <td>
          <Moment format="HH:mm:ss" tz="UTC">{ this.props.root.created_at }</Moment>
        </td>
        <td>{ this.props.root.pool }</td>
        <td>
          <Explorer blockstream coin={ this.props.coin } block={ this.props.root.hash }/>
        </td>
        <td>
          { this.props.length != 1 && this.props.length <= 100 &&
            <span>
              <Explorer blockstream coin={ this.props.coin } block={ this.props.tip.hash }/>
            </span>
          }
        </td>
      </tr>
    )
  }
}

StaleCandidate.propTypes = {
}

export default StaleCandidate
