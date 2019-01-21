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
   axios.get('/api/v1/nodes/coin/' + coin).then(function (response) {
     return response.data;
   }).then(function (nodes) {
     var unique = (arrArg) => arrArg.filter((elem, pos, arr) => arr.findIndex(x => x.best.hash === elem.best.hash) == pos)

     var chaintips_and_common = unique(nodes.map(node => ({best: node.best_block, common: node.common_block})));

     this.setState({
       coin: coin,
       nodes: nodes,
       chaintips: chaintips_and_common.map(x => x.best),
       chaintips_common_block: chaintips_and_common.map(x => x.common)
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
              The last common block between ABC and SV was mined. Height: 556766, Log2(PoW): 87.723, Hash: 00000000000000000102d94fde9bd0807a2cc7582fe85dd6349b73ce4e8d9322 at 17:52 UTC on 15th November 2018
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
                      Accumulated log2(PoW): <NumberFormat value={chaintip.work} displayType={'text'} decimalScale={6} fixedDecimalScale={true} />
                      { this.state.chaintips_common_block[index] &&
                        <span>
                          <br/>
                          Coins mined since the split: <NumberFormat value={ 12.5*(chaintip.height - this.state.chaintips_common_block[index].height) } displayType={'text'} thousandSeparator={true} />
                          <br/>
                          Estimated cost of mining since the split: US$<NumberFormat value={ 0.00000144041*(Math.pow(2, chaintip.work) - Math.pow(2, this.state.chaintips_common_block[index].work)) / Math.pow(10,12) } displayType={'text'} decimalScale={0} thousandSeparator={true} />
                        </span>
                      }
                    </p>
                    Nodes:
                    <ul>
                    {this.state.nodes.filter(o => o.best_block.hash == chaintip.hash).map(function (node, index) {
                      var version = node.version.pad(8).split( /(?=(?:..)*$)/ ).map(Number)
                      return (
                        <li key={node.id} className="pull-left node-info">
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
