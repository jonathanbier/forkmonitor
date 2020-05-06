import React from 'react';

import NumberFormat from 'react-number-format';

class InflationTooltip extends React.Component {
  render() {
    return(
      <ul style={{paddingLeft: 0, marginBottom: 0}}>
        { this.props.txOutset != null &&
          <li>Coin supply:&nbsp;
            <NumberFormat
                value={ this.props.txOutset.total_amount }
                displayType={'text'}
                thousandSeparator={true}
                fixedDecimalScale={true}
                decimalScale={8}
            />
          </li>
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
