import React from 'react';

import axios from 'axios';

import Moment from 'react-moment';
import NumberFormat from 'react-number-format';

import {
    Container,
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

axios.defaults.headers.post['Content-Type'] = 'application/json'

class Nodes extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      coin: props.coin,
      nodes: [],
      pow: []
    };

    this.getNodes = this.getNodes.bind(this);
  }

  componentDidMount() {
    this.getNodes()
  }

  getNodes() {
   axios.get('/api/v1/nodes/' + this.state.coin).then(function (response) {
     return response.data;
   }).then(function (nodes) {
     this.setState({
       nodes: nodes,
       pow: [...(new Set(nodes.map(node => node.best_block.work)))]
     });

   }.bind(this)).catch(function (error) {
     console.error(error);
   });
 }

  render() {
      return(
          <Container>
              {this.state.pow.map(function (work) {
                return (
                  <Row key={work}><Col>
                    <Breadcrumb>
                      <BreadcrumbItem active>
                        Accumulated log2(PoW)=<NumberFormat value={work} displayType={'text'} decimalScale={3} fixedDecimalScale={true} />
                      </BreadcrumbItem>
                    </Breadcrumb>
                    {this.state.nodes.filter(o => o.best_block.work == work).map(function (node, index) {
                      var version = node.version.pad(8).split( /(?=(?:..)*$)/ ).map(Number)
                      return (
                        <Row key={node.pos} className="pull-left node-info">
                          <Col>
                            <h4>{node.name} {version[0]}.{version[1]}.{version[2]}
                              {version[3] > 0 &&
                                <span>.{version[3]}</span>
                              }
                            </h4>
                            {node.unreachable_since!=null &&
                              <Badge color="warning">Offline</Badge>
                            }
                            <ul>
                              {node.unreachable_since!=null &&
                                <li>Offline since {node.unreachable_since}</li>
                              }
                              <li>Height: {node.best_block.height} (<Moment format="YYYY-MM-DD HH:mm" parse="X">{node.best_block.timestamp}</Moment>)</li>
                              <li>Hash: {node.best_block.hash}</li>
                            </ul>
                          </Col>
                        </Row>)
                    }.bind(this))}
                    {work!=this.state.pow[-1] &&
                      <hr/>
                    }
                  </Col></Row>)
              }.bind(this))}
          </Container>
      );
  }
}
export default Nodes
