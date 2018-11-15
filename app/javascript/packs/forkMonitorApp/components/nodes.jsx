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
    Breadcrumb,
    TabPane,
    UncontrolledAlert
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
      coin: props.match.params.coin,
      nodes: [],
      chaintips: []
    };

    this.getNodes = this.getNodes.bind(this);
  }

  componentDidMount() {
    this.getNodes(this.state.coin);
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
   axios.get('/api/v1/nodes/' + coin).then(function (response) {
     return response.data;
   }).then(function (nodes) {
     var unique = (arrArg) => arrArg.filter((elem, pos, arr) => arr.findIndex(x => x.hash === elem.hash) == pos)

     this.setState({
       coin: coin,
       nodes: nodes,
       chaintips: unique(nodes.map(node => node.best_block))
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
              Bitcoin Cash is expected to conduct a hardfork upgrade at about 16:40UTC on 15th November 2018
            </UncontrolledAlert>
          }
          <Container>
              {(this.state && this.state.chaintips || []).map(function (chaintip, index) {
                return (
                  <Row key={chaintip.hash}><Col>
                    <Breadcrumb>
                      <BreadcrumbItem active>
                        Chaintip: { chaintip.hash }
                      </BreadcrumbItem>
                    </Breadcrumb>
                    <p>
                     Height: { chaintip.height } (<Moment format="YYYY-MM-DD HH:mm" parse="X">{chaintip.timestamp}</Moment>)
                     <br/>
                     Accumulated log2(PoW): <NumberFormat value={chaintip.work} displayType={'text'} decimalScale={3} fixedDecimalScale={true} />
                    </p>
                    Nodes:
                    <ul>
                    {this.state.nodes.filter(o => o.best_block.hash == chaintip.hash).map(function (node, index) {
                      var version = node.version.pad(8).split( /(?=(?:..)*$)/ ).map(Number)
                      return (
                        <li key={node.pos} className="pull-left node-info">
                          <b>
                            {node.name} {version[0]}.{version[1]}.{version[2]}
                                {version[3] > 0 &&
                                  <span>.{version[3]}</span>
                                }
                              {node.unreachable_since!=null &&
                                <Badge color="warning">Offline</Badge>
                              }
                            </b>
                        </li>)
                    }.bind(this))}
                    </ul>
                    {  index != this.state.chaintips.length - 1 &&
                      <hr/>
                    }
                  </Col>
                  </Row>
              )}.bind(this))}
          </Container>
        </TabPane>
      );
  }
}
export default Nodes
