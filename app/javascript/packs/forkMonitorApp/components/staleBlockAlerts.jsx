import React from 'react';

import axios from 'axios';

import NodeName from './nodeName';
import AlertStale from './alertStale';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class StaleBlockAlerts extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      fresh: true
    };
  }

  componentDidMount() {
    this.getStaleBlocks();
  }

  componentDidUpdate() {
    if (this.state.fresh) {
      this.getStaleBlocks();
      this.setState({
          fresh: false
      });
    }

  }

   getStaleBlocks() {
     axios.get(`/api/v1/stale_candidates.json`).then(function (response) {
       return response.data;
     }).then(function (stale_candidates) {
       this.setState({
         stale_candidates: stale_candidates,
       });
    }.bind(this)).catch(function (error) {
      console.error(error);
    });
  }

  render() {
    return(
      <div>
        {(this.state && this.state.stale_candidates || []).filter(
          c => this.props.currentHeight - c.height < 1000
        ).map(function (candidate) {
          return (<AlertStale candidate={ candidate } currentHeight={ this.props.currentHeight } key={ candidate.height }/>)
        }.bind(this))}
      </div>
    );
  }
}
export default StaleBlockAlerts
