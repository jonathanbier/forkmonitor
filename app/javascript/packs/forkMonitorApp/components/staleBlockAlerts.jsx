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
    this.getStaleBlocks(this.props.coin);
  }

  static getDerivedStateFromProps(props, state) {
    const currentCoin = state.coin;
    const nextCoin = props.coin;

    if (currentCoin !== nextCoin) {
      state.coin = props.coin;
      state.fresh = true;
    }

    return state;
  }

  componentDidUpdate() {
    if (this.state.fresh) {
      this.getStaleBlocks(this.state.coin);
      this.setState({
          fresh: false
      });
    }

  }

   getStaleBlocks(coin) {
     axios.get(`/api/v1/stale_candidates/${ coin }`).then(function (response) {
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
          c => this.props.currentHeight - c.height < 6
        ).map(function (candidate) {
          return (<AlertStale candidate={ candidate }  coin={ this.state.coin } currentHeight={ this.props.currentHeight } key={ candidate.height }/>)
        }.bind(this))}
      </div>
    );
  }
}
export default StaleBlockAlerts
