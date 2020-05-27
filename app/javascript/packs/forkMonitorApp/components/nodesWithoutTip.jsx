import React from 'react';

import PropTypes from 'prop-types';

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
                      cableApp={ this.props.cableApp }
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

NodesWithoutTip.propTypes = {
  cableApp: PropTypes.any.isRequired
}

export default NodesWithoutTip
