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
      common_block: props.common_block,
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
            { this.state.common_block &&
              <span>
                <br/>
                Coins mined since the split: <NumberFormat value={ 12.5*(this.state.chaintip.height - this.state.common_block.height) } displayType={'text'} thousandSeparator={true} />
                <br/>
                Estimated cost of mining since the split: US$<NumberFormat value={ 0.00000144041*(Math.pow(2, this.state.chaintip.work) - Math.pow(2, this.state.common_block.work)) / Math.pow(10,12) } displayType={'text'} decimalScale={0} thousandSeparator={true} />
              </span>
            }
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
