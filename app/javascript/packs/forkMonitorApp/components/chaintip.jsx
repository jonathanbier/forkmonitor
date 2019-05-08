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
              Chaintip: { this.state.chaintip.hash }
            </BreadcrumbItem>
          </Breadcrumb>
          <p>
            Height: <NumberFormat value={ this.state.chaintip.height } displayType={'text'} thousandSeparator={true} /> (<Moment format="YYYY-MM-DD HH:mm:ss" parse="X">{this.state.chaintip.timestamp}</Moment> UTC)
            <br/>
            Accumulated log2(PoW): <NumberFormat value={this.state.chaintip.work} displayType={'text'} decimalScale={6} fixedDecimalScale={true} />
          </p>
          Nodes:
          <ul>
          {this.state.nodes.filter(o => o.best_block && o.best_block.hash == this.state.chaintip.hash).map(function (node, index) {
            return (
              <Node node={ node } key={node.id} className="pull-left node-info" />
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
