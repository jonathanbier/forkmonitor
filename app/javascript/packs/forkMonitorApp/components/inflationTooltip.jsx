import React from 'react';

import NumberFormat from 'react-number-format';

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faCheckCircle } from '@fortawesome/free-solid-svg-icons'
import { faTimesCircle } from '@fortawesome/free-solid-svg-icons'

class InflationTooltip extends React.Component {
  render() {
    const txOutset = this.props.txOutset || this.props.lastTxOutset;
    return(
      <ul style={{paddingLeft: 0, marginBottom: 0}}>
        <li>Height:&nbsp;
          <NumberFormat
              value={ txOutset.height }
              displayType={'text'}
              thousandSeparator={true}
          />
          {
            this.props.txOutset == null &&
            <span> (processing new blocks...)</span>
          }
        </li>
        { txOutset != null &&
          <span>
            <li>Coin supply:&nbsp;
              <NumberFormat
                  value={ txOutset.total_amount  }
                  displayType={'text'}
                  thousandSeparator={true}
                  fixedDecimalScale={true}
                  decimalScale={1}
              />&nbsp;
              <FontAwesomeIcon
                className={ txOutset == null ? "fa-pulse" : (!txOutset.inflated ? "text-success" : "text-danger") }
                icon={ !txOutset.inflated ? faCheckCircle : faTimesCircle }
              />
            </li>
            <li>Expected supply:&nbsp;
              <NumberFormat
                  value={ txOutset.expected_supply }
                  displayType={'text'}
                  thousandSeparator={true}
                  fixedDecimalScale={true}
                  decimalScale={1}
              />
            </li>
            <li>Change from previous block:&nbsp;
              <NumberFormat
                  value={ txOutset.increase }
                  displayType={'text'}
                  thousandSeparator={true}
              />
            </li>
            <li>Expected change:&nbsp;
              <NumberFormat
                  value={ txOutset.expected_increase }
                  displayType={'text'}
                  thousandSeparator={true}

              />
            </li>
          </span>
        }
      </ul>
    )
  }
}
export default InflationTooltip
