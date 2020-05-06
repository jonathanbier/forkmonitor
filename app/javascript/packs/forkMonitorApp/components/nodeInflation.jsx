import React from 'react';

import { Badge } from 'reactstrap';
import { Tooltip } from 'reactstrap';

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faCheckCircle } from '@fortawesome/free-solid-svg-icons'
import { faTimesCircle } from '@fortawesome/free-solid-svg-icons'
import { faSpinner } from '@fortawesome/free-solid-svg-icons'

import NumberFormat from 'react-number-format';

import InflationTooltip from './inflationTooltip';

class NodeInflation extends React.Component {
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
      <span id={`inflation-node-${ this.props.node.id }`} className="font-weight-light">Supply:&nbsp;
        { this.props.txOutset != null &&
          <span>
            <NumberFormat
              value={ this.props.txOutset.total_amount }
              displayType={'text'}
              thousandSeparator={true}
              fixedDecimalScale={true}
              decimalScale={1}
            />&nbsp;
          </span>
        }
        <FontAwesomeIcon
          className={ this.props.txOutset == null ? "fa-pulse" : (!this.props.txOutset.inflated ? "text-success" : "text-danger") }
          icon={ this.props.txOutset == null ? faSpinner : (!this.props.txOutset.inflated ? faCheckCircle : faTimesCircle) }
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
            <InflationTooltip node={ this.props.node } txOutset={ this.props.txOutset }  />
          </Tooltip>
        }
      </span>
    )
  }
}
export default NodeInflation
