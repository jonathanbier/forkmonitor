import React from 'react';

import Moment from 'react-moment';
import NumberFormat from 'react-number-format';

import {
    Row,
    Col,
    BreadcrumbItem,
    Breadcrumb
} from 'reactstrap';

import Node from './node';

class Chaintip extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      coin: props.coin,
      nodes: props.nodes,
      chaintip: props.chaintip,
      index: props.index,
      last: props.last
    };
  }

  render() {
    return(
        <Row><Col>
          <Breadcrumb>
            <BreadcrumbItem active className="chaintip-hash">
              Chaintip: { this.state.chaintip.block.hash }
            </BreadcrumbItem>
          </Breadcrumb>
          <p>
            Height: <NumberFormat value={ this.state.chaintip.block.height } displayType={'text'} thousandSeparator={true} /> (<Moment format="YYYY-MM-DD HH:mm:ss" parse="X">{this.state.chaintip.block.timestamp}</Moment> UTC)
            <br/>
            Accumulated log2(PoW): <NumberFormat value={this.state.chaintip.block.work} displayType={'text'} decimalScale={6} fixedDecimalScale={true} />
          </p>
          Nodes:
          <ul>
          {this.state.chaintip.nodes.map(function (node, index) {
            return (
              <Node node={ node } key={node.id} chaintip={ this.state.chaintip } className="pull-left node-info" />
            )
          }.bind(this))}
          </ul>
          {  this.state.last &&
            <hr/>
          }
        </Col>
      </Row>
    )
  }
}
export default Chaintip
