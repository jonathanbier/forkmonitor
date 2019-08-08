import React from 'react';

import {
    Row,
    Col,
    BreadcrumbItem,
    Breadcrumb,
    Table
} from 'reactstrap';

import Node from './node';
import ChaintipInfo from './chaintipInfo';

class Chaintip extends React.Component {
  render() {
    return(
        <Row><Col>
          <Breadcrumb>
            <BreadcrumbItem active className="chaintip-hash">
              Chaintip: { this.props.chaintip.block.hash }
            </BreadcrumbItem>
          </Breadcrumb>
          <ChaintipInfo chaintip={ this.props.chaintip }/>
          <small>
            <Table striped>
              <tbody>
                {this.props.chaintip.nodes.map(function (node, index) {
                  return (
                    <Node node={ node } key={node.id} chaintip={ this.props.chaintip } className="pull-left node-info" />
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
export default Chaintip
