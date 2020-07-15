import React from 'react';

import axios from 'axios';

import NodeName from './nodeName';
import AlertInvalid from './alertInvalid';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class InvalidBlockAlerts extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      fresh: true
    };
  }

  componentDidMount() {
    this.getInvalidBlocks(this.props.coin);
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
      this.getInvalidBlocks(this.state.coin);
      this.setState({
          fresh: false
      });
    }

  }

   getInvalidBlocks(coin) {
     axios.get('/api/v1/invalid_blocks?coin=' + coin).then(function (response) {
       return response.data;
     }).then(function (invalid_blocks) {
       this.setState({
         invalid_blocks: invalid_blocks
       });
    }.bind(this)).catch(function (error) {
      console.error(error);
    });
  }

  render() {
    return(
      <div>
        {(this.state && this.state.invalid_blocks || []).map(function (invalid_block) {
          return (<AlertInvalid invalidBlock={ invalid_block }  key={ invalid_block.id }/>)
        }.bind(this))}
      </div>
    );
  }
}
export default InvalidBlockAlerts
