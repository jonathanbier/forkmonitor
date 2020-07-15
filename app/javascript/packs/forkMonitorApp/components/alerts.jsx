import React from 'react';

import InflatedBlockAlerts from './inflatedBlockAlerts'
import InvalidBlockAlerts from './invalidBlockAlerts'

class Alerts extends React.Component {
  render() {
    return(
      <div>
        <br />
        <InvalidBlockAlerts coin={ this.props.coin } />
        <InflatedBlockAlerts coin={ this.props.coin } />
      </div>
    );
  }
}
export default Alerts
