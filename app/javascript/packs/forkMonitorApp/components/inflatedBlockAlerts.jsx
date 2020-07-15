import React from 'react';

import axios from 'axios';

import NodeName from './nodeName';
import AlertInflation from './alertInflation';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class InflatedBlockAlerts extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      fresh: true
    };
  }

  componentDidMount() {
    this.getInflatedBlocks(this.props.coin);
  }

  static getDerivedStateFromProps(props, state) {
    const currentCoin = state.coin;
    const nextCoin = props.coin;

    if (currentCoin !== nextCoin) {
      state.coin = props.coin;
      state.nodesWithoutTip = [];
      state.chaintips = [];
      state.fresh = true;
    }

    return state;
  }

  componentDidUpdate() {
    if (this.state.fresh) {
      this.getInflatedBlocks(this.state.coin);
      this.setState({
          fresh: false
      });
    }

  }

  getInflatedBlocks(coin) {
    axios.get('/api/v1/inflated_blocks?coin=' + coin).then(function (response) {
      return response.data;
    }).then(function (inflated_blocks) {
      this.setState({
        inflated_blocks: inflated_blocks
      });
    }.bind(this)).catch(function (error) {
      console.error(error);
    });
  }

  render() {
    return(
      <div>
        {(this.state && this.state.inflated_blocks || []).map(function (inflated_block) {
          return (<AlertInflation inflatedBlock={ inflated_block }  key={ inflated_block.id }/>)
        }.bind(this))}
      </div>
    );
  }
}
export default InflatedBlockAlerts
