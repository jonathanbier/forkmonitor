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
import BlockInfo from './blockInfo';

class Chaintip extends React.Component {
  render() {
    return(
        <Row><Col>
          <Breadcrumb className="chaintip-header">
            <BreadcrumbItem className="chaintip-hash">
              Chaintip: { this.props.chaintip.block.hash }
            </BreadcrumbItem>
          </Breadcrumb>
          <BlockInfo block={ this.props.chaintip.block }/>
          <small>
            <Table striped>
              <tbody>
                {this.props.chaintip.nodes.map(function (node, index) {
                  return (
                    <Node
                      node={ node }
                      key={node.id}
                      chaintip={ this.props.chaintip }
                      cableApp={ this.props.cableApp }
                      className="pull-left node-info"
                    />
                  )
                }.bind(this))}
              </tbody>
            </Table>
          </small>
          {  this.props.last &&
            <hr/>
          }
        </Col>
      </Row>
    )
  }
}

Chaintip.propTypes = {
  cableApp: PropTypes.any.isRequired
}

export default Chaintip
