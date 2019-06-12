import React from 'react';

import axios from 'axios';

import {
    Container,
    TabPane,
    UncontrolledAlert
} from 'reactstrap';

import Chaintip from './chaintip';
import NodesWithoutTip from './nodesWithoutTip';
import NodeName from './nodeName';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class Nodes extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      coin: props.match.params.coin,
      nodes: [],
      chaintips: [],
      nodesWithoutTip: [],
      invalid_blocks: []
    };

    this.getNodes = this.getNodes.bind(this);
    this.getInvalidBlocks = this.getInvalidBlocks.bind(this);
  }

  componentDidMount() {
    this.getNodes(this.state.coin);
    this.getInvalidBlocks(this.state.coin);
  }

  componentWillReceiveProps(nextProps) {
    const currentCoin = this.state && this.state.coin;
    const nextCoin = nextProps.match.params.coin;

    if (currentCoin !== nextCoin) {
      this.setState({
        nodes: [],
        nodesWithoutTip: [],
        chaintips: []
      });
      this.getNodes(nextProps.match.params.coin);
    }

  }

  getNodes(coin) {
    axios.get('/api/v1/nodes/coin/' + coin).then(function (response) {
      return response.data;
    }).then(function (nodes) {
      var unique = (arrArg) => arrArg.filter((elem, pos, arr) => arr.findIndex(x => x && elem && x.hash === elem.hash) == pos)

      var chaintips = unique(nodes.map(node => (node.best_block)));

      this.setState({
        coin: coin,
        nodes: nodes,
        chaintips: chaintips,
        nodesWithoutTip: nodes.filter(node => node.best_block == null)
      });

      }.bind(this)).catch(function (error) {
        console.error(error);
      });
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
        <TabPane align="left" >
          <br />
          { (this.state.coin === "btc" && this.state && this.state.invalid_blocks || []).map(function (invalid_block) {
            return (
                <UncontrolledAlert color="danger" key={invalid_block.id}>
                  <NodeName node={invalid_block.node} /> considers
                  block { invalid_block.block.hash } at height { invalid_block.block.height } invalid.
                  { invalid_block.block.first_seen_by &&
                    <span>
                      { } This block was first seen and accepted as valid by <NodeName node={invalid_block.block.first_seen_by} />.
                    </span>
                  }

                </UncontrolledAlert>
            )
          }.bind(this))}
          <Container>
              {(this.state && this.state.chaintips || []).map(function (chaintip, index) {
                return (<Chaintip
                  key={ chaintip.hash }
                  coin={ this.state.coin }
                  chaintip={ chaintip }
                  nodes={ this.state.nodes }
                  index={ index }
                  last={ index != this.state.chaintips.length - 1 }
                  invalid_blocks={ this.state.invalid_blocks }
                />)
              }.bind(this))}
              { this.state.nodesWithoutTip.length > 0 &&
                <NodesWithoutTip coin={ this.state.coin } nodes={ this.state.nodesWithoutTip } />
              }
          </Container>

        </TabPane>
      );
  }
}
export default Nodes
