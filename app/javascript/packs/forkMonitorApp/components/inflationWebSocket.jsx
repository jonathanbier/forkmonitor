import React, { Component } from 'react';

import PropTypes from 'prop-types';

class InflationWebSocket extends Component {
    componentDidMount() {
        this.props.cableApp.inflation = this.props.cableApp.cable.subscriptions.create({
            channel: 'InflationChannel',
            node: this.props.node.id
        },
        {
            received: (txOutset) => {
              this.props.updateTxOutset(txOutset)
            }
        })
    }

    render() {
        return (
            <div></div>
        )
    }
}

InflationWebSocket.propTypes = {
  cableApp: PropTypes.any.isRequired,
  node: PropTypes.any.isRequired,
  updateTxOutset: PropTypes.func.isRequired
}

export default InflationWebSocket
