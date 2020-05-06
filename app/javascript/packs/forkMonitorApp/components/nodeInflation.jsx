import React from 'react';

import { Badge } from 'reactstrap';

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faCheckCircle } from '@fortawesome/free-solid-svg-icons'
import { faTimesCircle } from '@fortawesome/free-solid-svg-icons'
import { faSpinner } from '@fortawesome/free-solid-svg-icons'

import NumberFormat from 'react-number-format';

class NodeInflation extends React.Component {
  render() {
    return(
      <span className="font-weight-light">Supply:&nbsp;
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
      </span>
    )
  }
}
export default NodeInflation
