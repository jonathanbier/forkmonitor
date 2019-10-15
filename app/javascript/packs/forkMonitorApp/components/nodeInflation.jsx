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
      <span>Coin supply:&nbsp;
        {
          this.props.txOutset == null && (
            <FontAwesomeIcon className="fa-pulse" icon={faSpinner} />
          )
        }
        {
          this.props.txOutset != null &&
          <span>
            <NumberFormat
              value={ this.props.txOutset.total_amount }
              displayType={'text'}
              thousandSeparator={true}
              fixedDecimalScale={true}
              decimalScale={1}
            />&nbsp;
            {
              !this.props.txOutset.inflated &&
              <FontAwesomeIcon className="text-success" icon={faCheckCircle} />
            }
            {
              this.props.txOutset.inflated &&
              <FontAwesomeIcon className="text-danger" icon={faTimesCircle} />
            }
          </span>
        }
      </span>
    )
  }
}
export default NodeInflation
