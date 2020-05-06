import React from 'react';

import NumberFormat from 'react-number-format';

class InflationTooltip extends React.Component {
  render() {
    return(
      <ul style={{paddingLeft: 0, marginBottom: 0}}>
        { this.props.txOutset != null &&
          <span>
            <li>Coin supply:&nbsp;
              <NumberFormat
                  value={ this.props.txOutset.total_amount }
                  displayType={'text'}
                  thousandSeparator={true}
                  fixedDecimalScale={true}
                  decimalScale={1}
              />
            </li>
            <li>Expected supply:&nbsp;
              <NumberFormat
                  value={ this.props.txOutset.expected_supply }
                  displayType={'text'}
                  thousandSeparator={true}
                  fixedDecimalScale={true}
                  decimalScale={1}
              />
            </li>
            <li>Change from previous block:&nbsp;
              <NumberFormat
                  value={ this.props.txOutset.increase }
                  displayType={'text'}
                  thousandSeparator={true}
              />
            </li>
            <li>Expected change:&nbsp;
              <NumberFormat
                  value={ this.props.txOutset.expected_increase }
                  displayType={'text'}
                  thousandSeparator={true}

              />
            </li>
          </span>
        }
        <li>Block height:&nbsp;
          <NumberFormat
              value={ this.props.node.height }
              displayType={'text'}
              thousandSeparator={true}
          />
        </li>
      </ul>
    )
  }
}
export default InflationTooltip
