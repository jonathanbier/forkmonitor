import React from 'react';

import axios from 'axios';

import Moment from 'react-moment';

import {
    Container,
    Row,
    Col,
    Badge
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
      nodes: []
    };

    this.getNodes = this.getNodes.bind(this);
  }

  componentDidMount() {
    this.getNodes()
  }

  getNodes() {
   axios.get('/api/v1/nodes').then(function (response) {
     return response.data;
   }).then(function (nodes) {
     this.setState({
       nodes: nodes
     });
   }.bind(this)).catch(function (error) {
     console.error(error);
   });
 }

  render() {
      return(
          <Container>
            {this.state.nodes.map(function (node, index) {
              var version = node.version.pad(8).split( /(?=(?:..)*$)/ ).map(Number)
              return (
                <Row key={node.pos} className="node-info">
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
                      <li>Work: {node.best_block.work}</li>
                    </ul>
                  </Col>
                </Row>);
            }.bind(this))}
          </Container>
      );
  }
}
export default Nodes