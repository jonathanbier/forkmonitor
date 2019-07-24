import React from 'react';

import Moment from 'react-moment';
import 'moment-timezone'
import NumberFormat from 'react-number-format';

import {
    Row,
    Col,
    BreadcrumbItem,
    Breadcrumb
} from 'reactstrap';

import Node from './node';

class Chaintip extends React.Component {
  render() {
    return(
        <Row><Col>
          <Breadcrumb>
            <BreadcrumbItem active className="chaintip-hash">
              Chaintip: { this.props.chaintip.block.hash }
            </BreadcrumbItem>
          </Breadcrumb>
          <p className="chaintip-info">
            Height: <NumberFormat value={ this.props.chaintip.block.height } displayType={'text'} thousandSeparator={true} /> (<Moment format="YYYY-MM-DD HH:mm:ss" tz="UTC" parse="X">{this.props.chaintip.block.timestamp}</Moment> UTC)
            <br/>
            Accumulated log2(PoW): <NumberFormat value={this.props.chaintip.block.work} displayType={'text'} decimalScale={6} fixedDecimalScale={true} />
            { this.props.chaintip.block.size &&
                <span><br />Latest blocksize: <NumberFormat value={ this.props.chaintip.block.size / 1000000 } displayType={'text'} thousandSeparator={true} decimalScale={2} fixedDecimalScale={true} /> MB</span>
            }
            <br />
            Latest block transaction count: <NumberFormat value={ this.props.chaintip.block.tx_count } displayType={'text'} thousandSeparator={true} />
          </p>
          Nodes:
          <ul>
          {this.props.chaintip.nodes.map(function (node, index) {
            return (
              <Node node={ node } key={node.id} chaintip={ this.props.chaintip } className="pull-left node-info" />
            )
          }.bind(this))}
          </ul>
          {  this.props.last &&
            <hr/>
          }
        </Col>
      </Row>
    )
  }
}
export default Chaintip
