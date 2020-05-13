import React from 'react';

import {
    Row,
    Col,
    BreadcrumbItem,
    Breadcrumb,
    Table
} from 'reactstrap';

import Node from './node';

class NodesWithoutTip extends React.Component {
  render() {
    return(
        <Row><Col>
          <Breadcrumb  className="chaintip-header">
            <BreadcrumbItem className="chaintip-hash">
              Syncing nodes
            </BreadcrumbItem>
          </Breadcrumb>
          <small>
            <Table striped>
              <tbody>
                {this.props.nodes.map(function (node) {
                  return (
                    <Node
                      node={ node }
                      key={node.id}
                      className="pull-left node-info"
                    />
                  )
                }.bind(this))}
                </tbody>
              </Table>
            </small>
          </Col>
      </Row>
    )
  }
}
export default NodesWithoutTip
