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
      txOutset: props.txOutset
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
        txOutset: newTxOutset
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
            <InflationTooltip node={ this.props.node } txOutset={ this.state.txOutset }  />
          </Tooltip>
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
