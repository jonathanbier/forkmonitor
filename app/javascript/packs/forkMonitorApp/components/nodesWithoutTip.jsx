import React from 'react';

import {
    Row,
    Col,
    BreadcrumbItem,
    Breadcrumb
} from 'reactstrap';

import Node from './node';

class NodesWithoutTip extends React.Component {
  render() {
    return(
        <Row><Col>
          <Breadcrumb>
            <BreadcrumbItem active>
              Syncing nodes
            </BreadcrumbItem>
          </Breadcrumb>
          <ul>
          {this.props.nodes.map(function (node) {
            return (
              <Node node={ node } key={node.id} className="pull-left node-info" />
            )
          }.bind(this))}
          </ul>
        </Col>
      </Row>
    )
  }
}
export default NodesWithoutTip
