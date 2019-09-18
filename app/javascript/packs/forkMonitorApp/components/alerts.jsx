import React from 'react';

import axios from 'axios';

import {
    UncontrolledAlert
} from 'reactstrap';

import NodeName from './nodeName';

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
          return (
            <UncontrolledAlert color="danger" key={invalid_block.id}>
              <NodeName node={invalid_block.node} /> considers
              block { invalid_block.block.hash } at height { invalid_block.block.height } invalid.
              This block was mined by { invalid_block.block.pool ? invalid_block.block.pool : "an unknown pool" }.
              { invalid_block.block.first_seen_by &&
                <span>
                  {} It was first seen and accepted as valid by <NodeName node={invalid_block.block.first_seen_by} />.
                </span>
              }
            </UncontrolledAlert>
          )
        }.bind(this))}
        {(this.state && this.state.inflated_blocks || []).map(function (inflated_block) {
          return (
            <UncontrolledAlert color="danger" key={inflated_block.id}>
              <NodeName node={inflated_block.node} /> detected inflation in
              block { inflated_block.block.hash } at height { inflated_block.block.height }.
              This block was mined by { inflated_block.block.pool ? inflated_block.block.pool : "an unknown pool" }.
              { inflated_block.block.first_seen_by &&
                <span>
                  {} It was first seen and accepted as valid by <NodeName node={inflated_block.block.first_seen_by} />.
                </span>
              }
            </UncontrolledAlert>
          )
        }.bind(this))}
      </div>
    );
  }
}
export default Alerts
