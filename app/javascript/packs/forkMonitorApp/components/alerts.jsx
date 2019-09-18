import React from 'react';

import axios from 'axios';

import NodeName from './nodeName';
import AlertInvalid from './alertInvalid';
import AlertInflation from './alertInflation';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class Alerts extends React.Component {
  constructor(props) {
    super(props);
    
    this.state = {
    };

    this.getInvalidBlocks = this.getInvalidBlocks.bind(this);
    this.getInflatedBlocks = this.getInflatedBlocks.bind(this);
  }
  
  componentDidMount() {
    this.getInvalidBlocks(this.props.coin);
    this.getInflatedBlocks(this.props.coin);
  }

  componentWillReceiveProps(nextProps) {
    const currentCoin = this.props.coin;
    const nextCoin = nextProps.coin;
    
    if (!this.state.invalid_blocks || currentCoin !== nextCoin) {
      this.setState({
        invalid_blocks: [],
        inflated_blocks: []
      });
      this.getInvalidBlocks(nextProps.coin);    
      this.getInflatedBlocks(nextProps.coin);    
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
        <br />
        {(this.state && this.state.invalid_blocks || []).map(function (invalid_block) {
          return (<AlertInvalid invalidBlock={ invalid_block }  key={ invalid_block.id }/>)
        }.bind(this))}
        {(this.state && this.state.inflated_blocks || []).map(function (inflated_block) {
          return (<AlertInflation inflatedBlock={ inflated_block }  key={ inflated_block.id }/>)
        }.bind(this))}
      </div>
    );
  }
}
export default Alerts
