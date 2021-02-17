import React from 'react';
import axios from 'axios';

import Explorer from './explorer';
import BlockInfo from './blockInfo';

import {
    Breadcrumb,
    BreadcrumbItem,
    Col,
    Container,
    TabPane,
    Row
} from 'reactstrap';

class Block extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      coin: props.match.params.coin,
      hash: props.match.params.hash,
      block: null,
    };
  }

  componentDidMount() {
    this.getBlock(this.state.coin, this.state.hash);
  }

  getBlock(coin, hash) {
    axios.get('/api/v1/blocks/hash/' + hash).then(function (response) {
      return response.data;
    }).then(function (block) {
      console.log(block);
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
                { this.state.hash } ({ this.state.coin.toUpperCase() })
              </BreadcrumbItem>
            </Breadcrumb>
          { this.state.block &&
            <p>Height: { this.state.block.height }</p>
          }
          </Col></Row>
        </Container>
      </TabPane>
    )
  }
}

export default Block
