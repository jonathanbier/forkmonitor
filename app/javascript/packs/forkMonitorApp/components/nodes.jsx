import React from 'react';

import {
    Container,
    Row,
    Col
} from 'reactstrap';

Number.prototype.pad = function(size) {
  var s = String(this);
  while (s.length < (size || 2)) {s = "0" + s;}
  return s;
}


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
   let request = new Request('/api/v1/nodes', {
     method: 'GET',
     headers: new Headers({
       'Content-Type': 'application/json'
     })
   });

   fetch(request).then(function (response) {
     return response.json();
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
                <Row key={node.pos}>
                  <Col>
                    <h4>{node.name} {version[0]}.{version[1]}.{version[2]}
                      {version[3] > 0 &&
                        <span>.{version[3]}</span>
                      }
                    </h4>
                    <ul>
                      <li>Height: {node.best_block.height}</li>
                      <li>Timestamp: {node.best_block.timestamp}</li>
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
