import React from 'react';

import InflatedBlockAlerts from './inflatedBlockAlerts'
import InvalidBlockAlerts from './invalidBlockAlerts'
import StaleBlockAlerts from './staleBlockAlerts'
import SoftforkAlerts from './softforkAlerts'

class Alerts extends React.Component {
  render() {
    return(
      <div>
        <br />
        <InvalidBlockAlerts coin={ this.props.coin } />
        <InflatedBlockAlerts coin={ this.props.coin } />
        { this.props.currentHeight &&
          <span>
            <StaleBlockAlerts coin={ this.props.coin } currentHeight={ this.props.currentHeight } />
            <SoftforkAlerts coin={ this.props.coin } currentHeight={ this.props.currentHeight } />
          </span>
        }
      </div>
    );
  }
}
export default Alerts
