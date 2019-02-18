import React from 'react';

import axios from 'axios';

import {
    Container,
    TabPane,
    UncontrolledAlert
} from 'reactstrap';

import Chaintip from './chaintip';
import NodeName from './nodeName';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class Nodes extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      coin: props.match.params.coin,
      nodes: [],
      chaintips: [],
      invalid_blocks: []
    };

    this.getNodes = this.getNodes.bind(this);
    this.getInvalidBlocks = this.getInvalidBlocks.bind(this);
  }

  componentDidMount() {
    this.getNodes(this.state.coin);

    if (this.state.coin == "btc") {
      this.getInvalidBlocks();
    }
  }

  componentWillReceiveProps(nextProps) {
    const currentCoin = this.state && this.state.coin;
    const nextCoin = nextProps.match.params.coin;

    if (currentCoin !== nextCoin) {
      this.setState({
        nodes: [],
        chaintips: []
      });
      this.getNodes(nextProps.match.params.coin);
    }

  }

  getNodes(coin) {
    axios.get('/api/v1/nodes/coin/' + coin).then(function (response) {
      return response.data;
    }).then(function (nodes) {
      var unique = (arrArg) => arrArg.filter((elem, pos, arr) => arr.findIndex(x => x.best.hash === elem.best.hash) == pos)

      var chaintips_and_common = unique(nodes.map(node => ({best: node.best_block, common: node.common_block})));

      this.setState({
        coin: coin,
        nodes: nodes,
        chaintips: chaintips_and_common.map(x => x.best),
        chaintips_common_block: chaintips_and_common.map(x => x.common)
      });

      }.bind(this)).catch(function (error) {
        console.error(error);
      });
   }

   getInvalidBlocks() {
     axios.get('/api/v1/invalid_blocks').then(function (response) {
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
          { this.state.coin === "bch" &&
            <UncontrolledAlert color="info">
              The last common block between ABC and SV was mined. Height: 556766, Log2(PoW): 87.723, Hash: 00000000000000000102d94fde9bd0807a2cc7582fe85dd6349b73ce4e8d9322 at 17:52 UTC on 15th November 2018
            </UncontrolledAlert>
          }
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
                  common_block={ this.state.chaintips_common_block[index] }
                  invalid_blocks={ this.state.invalid_blocks }
                />)
              }.bind(this))}
          </Container>
        </TabPane>
      );
  }
}
export default Nodes
