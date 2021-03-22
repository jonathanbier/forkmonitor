import React from 'react';

import PropTypes from 'prop-types';

import { Badge } from 'reactstrap';
import { Tooltip } from 'reactstrap';

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faCheckCircle } from '@fortawesome/free-solid-svg-icons'
import { faTimesCircle } from '@fortawesome/free-solid-svg-icons'
import { faSpinner } from '@fortawesome/free-solid-svg-icons'

import NumberFormat from 'react-number-format';

import InflationTooltip from './inflationTooltip';
import InflationWebSocket from './inflationWebSocket';

class NodeInflation extends React.Component {
  constructor(props) {
    super(props);

    this.toggle = this.toggle.bind(this);
    this.state = {
      tooltipOpen: false,
      txOutset: props.txOutset,
      lastTxOutset: props.lastTxOutset
    };
  }

  toggle() {
    this.setState({
      tooltipOpen: !this.state.tooltipOpen
    });
  }

  updateTxOutset = (newTxOutset) => {
    if (newTxOutset.height == this.props.node.height) {
      this.setState({
        txOutset: newTxOutset,
        lastTxOutset: newTxOutset
      })
    }
  }

  render() {
    return(
      <span id={`inflation-node-${ this.props.node.id }`} className="font-weight-light">Supply:&nbsp;
        { this.state.txOutset != null &&
          <span>
            <NumberFormat
              value={ this.state.txOutset.total_amount }
              displayType={'text'}
              thousandSeparator={true}
              fixedDecimalScale={true}
              decimalScale={1}
            />&nbsp;
          </span>
        }
        { // Node should either:
          // * have an up to date tx outset; or
          // * be reachable, not in IBD and have at least one recent tx outset
        }
        { ((this.props.node.mirror_unreachable_since == null && !this.props.node.mirror_ibd && this.state.lastTxOutset != null) || this.state.txOutset != null) &&
          <span>
            <FontAwesomeIcon
              className={ this.state.txOutset == null ? "fa-pulse" : (!this.state.txOutset.inflated ? "text-success" : "text-danger") }
              icon={ this.state.txOutset == null ? faSpinner : (!this.state.txOutset.inflated ? faCheckCircle : faTimesCircle) }
            />
            { !this.props.disableTooltip &&
              <Tooltip
                placement="auto"
                isOpen={this.state.tooltipOpen}
                target={`inflation-node-${ this.props.node.id }`}
                toggle={this.toggle}
                modifiers={{preventOverflow: { enabled: false } }, {hide: { enabled: false } } }
                style={{maxWidth: "100%", textAlign: "left"}}
              >
                <InflationTooltip node={ this.props.node } txOutset={ this.state.txOutset } lastTxOutset={ this.state.lastTxOutset }  />
              </Tooltip>
            }
          </span>
        }
        { this.props.node.mirror_unreachable_since != null && this.state.txOutset == null &&
          <span>
            <Badge color="warning">Offline</Badge>
            <Tooltip
              placement="auto"
              isOpen={this.state.tooltipOpen}
              target={`inflation-node-${ this.props.node.id }`}
              toggle={this.toggle}
              modifiers={{preventOverflow: { enabled: false } }, {hide: { enabled: false } } }
              style={{maxWidth: "100%", textAlign: "left"}}
            >
              <p>The dedicated inflation check node is currently offline</p>
            </Tooltip>
          </span>
        }
        { this.props.node.mirror_unreachable_since == null && this.props.node.mirror_ibd && this.state.txOutset == null &&
          <span>
            <Badge color="info">Syncing</Badge>
            <Tooltip
              placement="auto"
              isOpen={this.state.tooltipOpen}
              target={`inflation-node-${ this.props.node.id }`}
              toggle={this.toggle}
              modifiers={{preventOverflow: { enabled: false } }, {hide: { enabled: false } } }
              style={{maxWidth: "100%", textAlign: "left"}}
            >
              <p>The dedicated inflation check node is currently syncing</p>
            </Tooltip>
          </span>
        }
        <InflationWebSocket
          cableApp={ this.props.cableApp }
          node={ this.props.node }
          txOutset={ this.state.txOutset }
          updateTxOutset={ this.updateTxOutset }
        />
      </span>
    )
  }
}


NodeInflation.propTypes = {
  cableApp: PropTypes.any.isRequired
}

export default NodeInflation
