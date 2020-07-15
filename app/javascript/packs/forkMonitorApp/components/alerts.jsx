import React from 'react';

import InflatedBlockAlerts from './inflatedBlockAlerts'
import InvalidBlockAlerts from './invalidBlockAlerts'
import StaleBlockAlerts from './staleBlockAlerts'

class Alerts extends React.Component {
  render() {
    return(
      <div>
        <br />
        <InvalidBlockAlerts coin={ this.props.coin } />
        <InflatedBlockAlerts coin={ this.props.coin } />
        { this.props.currentHeight &&
          <StaleBlockAlerts coin={ this.props.coin } currentHeight={ this.props.currentHeight } />
        }
      </div>
    );
  }
}
export default Alerts
