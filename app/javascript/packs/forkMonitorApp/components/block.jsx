import React from 'react';
import axios from 'axios';

import Explorer from './explorer';
import BlockInfo from './blockInfo';
import Transaction from './transaction';

import NumberFormat from 'react-number-format';

import {
    Breadcrumb,
    BreadcrumbItem,
    Col,
    Container,
    TabPane,
    Row,
    Table
} from 'reactstrap';

class Block extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      hash: props.match.params.hash,
      block: null,
    };
  }

  componentDidMount() {
    this.getBlock(this.state.hash);
  }

  getBlock(hash) {
    axios.get('/api/v1/blocks/hash/' + hash).then(function (response) {
      return response.data;
    }).then(function (block) {
      this.setState({
        block: block,
      });
      }.bind(this)).catch(function (error) {
        console.error(error);
      });
   }

  render() {
    return(
      <TabPane align="left" >
        <Container>
          <Row><Col>
            <Breadcrumb className="chaintip-header">
              <BreadcrumbItem className="chaintip-hash">
                { this.state.hash }
              </BreadcrumbItem>
            </Breadcrumb>
            { this.state.block &&
              <div>
                <BlockInfo block={ this.state.block } extra />
                <h3>Predicted block transactions</h3>
                <p>
                  Both <a href={"https://miningpool.observer/template-and-block/" + this.state.block.hash}>Miningpool.Observer</a> and <a href={"https://mempool.space/block/" + this.state.block.hash}>Mempool.Space </a>
                  compare the mempool right before each block with the real block, in order to find differences in the transactions and amount of fees collected. Usually any difference
                  is due to timing coincidence and variations for how transactions propagate between nodes.
                </p>
              </div>
            }
          </Col></Row>
        </Container>
      </TabPane>
    )
  }
}

export default Block
