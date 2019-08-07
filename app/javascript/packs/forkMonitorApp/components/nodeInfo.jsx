import React from 'react';

import NodeBehind from './nodeBehind';

import { Tooltip } from 'reactstrap';

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faInfoCircle } from '@fortawesome/free-solid-svg-icons'

class NodeInfo extends React.Component {
  constructor(props) {
    super(props);

    this.toggle = this.toggle.bind(this);
    this.state = {
      tooltipOpen: false
    };
  }

  toggle() {
    this.setState({
      tooltipOpen: !this.state.tooltipOpen
    });
  }

  render() {
    return(
      <span>
      <span> <FontAwesomeIcon icon={faInfoCircle} href="#" id={`node-${ this.props.node.id }-info`} /></span>
        <Tooltip
          placement="auto"
          isOpen={this.state.tooltipOpen}
          target={`node-${ this.props.node.id }-info`}
          toggle={this.toggle}
          boundariesElement="window"
          modifiers={{preventOverflow: { enabled: false } }, {hide: { enabled: false } } }
          style={{maxWidth: "100%", textAlign: "left"}}
        >
          <NodeBehind chaintip={ this.props.chaintip } node={ this.props.node } min={ 1 } verbose={ true } />
          <ul style={{paddingLeft: 0, marginBottom: 0}}>
            <li>Operating system: { this.props.node.os }</li>
            <li>CPU: { this.props.node.cpu }</li>
            <li>RAM: { this.props.node.ram } GB</li>
            <li>Storage: { this.props.node.storage }</li>
            <li>Pruned: { this.props.node.pruned ? "Yes" : "No" }</li>
            <li>CVE-2018-17144 Inflation Exposure: { this.props.node.cve_2018_17144 ? "Yes" : "No" }</li>
            <li>Client release date: { this.props.node.released }</li>
          </ul>
        </Tooltip>
      </span>
    )
  }
}
export default NodeInfo
