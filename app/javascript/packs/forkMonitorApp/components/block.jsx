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
              <BlockInfo block={ this.state.block } extra />
            }
            <div>
              <h3>Predicted block transactions</h3>
              <p>We call <code>getblocktemplate</code> on our node several times
              per minute to construct a candidate block. We then compare the amount
              of fees collected to the real block. Usually any difference
              is due to timing coincidence and variations for how transactions
              propagate between nodes.</p>
              { this.state.block && this.state.block.template_txs_fee_diff &&
                <p>
                  This block contained <NumberFormat value={ Math.abs(this.state.block.template_txs_fee_diff) } displayType={'text'} decimalScale={8} fixedDecimalScale={true} /> BTC {
                    this.state.block.template_txs_fee_diff > 0 ? "more " : "less "
                  }
                  transaction fees than expected from our most recent template.
                </p>
              }
              { this.state.block &&
                <p>
                  For a more detailed analysis see <a href={"https://miningpool.observer/template-and-block/" + this.state.block.hash}>miningpool.observer</a>. It also shows an overview of which transactions are missing compared to the template, and which ones were unexpected.
                </p>
              }
            </div>
          </Col></Row>
        </Container>
      </TabPane>
    )
  }
}

export default Block
