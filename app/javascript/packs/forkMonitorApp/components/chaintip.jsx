import React from 'react';

import Moment from 'react-moment';
import NumberFormat from 'react-number-format';

import {
    Row,
    Col,
    Badge,
    BreadcrumbItem,
    Breadcrumb
} from 'reactstrap';

Number.prototype.pad = function(size) {
  var s = String(this);
  while (s.length < (size || 2)) {s = "0" + s;}
  return s;
}

class Chaintip extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
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
            <BreadcrumbItem active>
              Chaintip: { this.state.chaintip.hash }
            </BreadcrumbItem>
          </Breadcrumb>
          <p>
            Height: { this.state.chaintip.height } (<Moment format="YYYY-MM-DD HH:mm" parse="X">{this.state.chaintip.timestamp}</Moment>)
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
          {this.state.nodes.filter(o => o.best_block.hash == this.state.chaintip.hash).map(function (node, index) {
            var version = node.version.pad(8).split( /(?=(?:..)*$)/ ).map(Number)
            return (
              <li key={node.id} className="pull-left node-info">
                <b>
                  {node.name} {version[0]}.{version[1]}.{version[2]}
                      {version[3] > 0 &&
                        <span>.{version[3]}</span>
                      }
                    {node.unreachable_since!=null &&
                      <span> <Badge color="warning">Offline</Badge></span>
                    }
                    {node.ibd &&
                      <span> <Badge color="info">Syncing</Badge></span>
                    }
                  </b>
              </li>)
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
