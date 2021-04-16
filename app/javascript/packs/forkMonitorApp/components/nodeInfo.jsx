import React from 'react';

import NodeBehind from './nodeBehind';

import { Tooltip } from 'reactstrap';
import NumberFormat from 'react-number-format';

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
          modifiers={{preventOverflow: { enabled: false } }, {hide: { enabled: false } } }
          style={{maxWidth: "100%", textAlign: "left"}}
        >
          <NodeBehind chaintip={ this.props.chaintip } node={ this.props.node } verbose={ true } />
          <ul style={{paddingLeft: 0, marginBottom: 0}}>
            { this.props.node.ibd &&
              <li>Sync height: { this.props.node.sync_height }</li>
            }
            <li>Operating system: { this.props.node.os }</li>
            <li>CPU: { this.props.node.cpu }</li>
            <li>RAM: { this.props.node.ram } GB</li>
            <li>Storage: { this.props.node.storage }</li>
            <li>Pruned: { this.props.node.pruned ? "Yes" : "No" }</li>
            <li>Transaction index: { this.props.node.txindex ? "Yes" : "No" }</li>
            <li>CVE-2018-17144 Inflation Exposure: { this.props.node.cve_2018_17144 ? "Yes" : "No" }</li>
            <li>Client release date: { this.props.node.released }</li>
            { this.props.node.mempool_count != null &&
              <li>
                Mempool: { this.props.node.mempool_count } transactions&nbsp;
                (<NumberFormat value={ this.props.node.mempool_bytes / 1000 / 1000 } displayType={'text'} decimalScale={1} fixedDecimalScale={true} thousandSeparator={true} />&nbsp;
                { this.props.node.mempool_max != null &&
                  <span>
                    of <NumberFormat value={ this.props.node.mempool_max / 1000 / 1000 } displayType={'text'} decimalScale={0} fixedDecimalScale={true} thousandSeparator={true} />&nbsp;
                  </span>
                }
                MB)
              </li>
            }
            { this.props.node.bip9_softforks != null && this.props.node.bip9_softforks.length > 0 &&
              <div>
              <li>BIP 9 softforks</li>
              <ul>
                { this.props.node.bip9_softforks.map(function (fork, index) { return (
                  <li key={ index }>
                    { fork.name }: { fork.status }
                    { fork.height != null &&
                      <span>&nbsp;since block <NumberFormat value={ fork.height } displayType={'text'} thousandSeparator={true} /></span>
                    }
                  </li>
                )})}
              </ul>
              </div>
            }
            { this.props.node.bip8_softforks != null && this.props.node.bip8_softforks.length > 0 &&
              <div>
              <li>BIP 8 softforks</li>
              <ul>
                { this.props.node.bip8_softforks.map(function (fork, index) { return (
                  <li key={ index }>
                    { fork.name }: { fork.status }
                    { fork.height != null &&
                      <span>&nbsp;since block <NumberFormat value={ fork.height } displayType={'text'} thousandSeparator={true} /></span>
                    }
                  </li>
                )})}
              </ul>
              </div>
            }
          </ul>
        </Tooltip>
      </span>
    )
  }
}
export default NodeInfo
