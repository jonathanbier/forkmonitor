import React from 'react';

import axios from 'axios';

import NumberFormat from 'react-number-format';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class LightningStats extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      stats: null,
    };

    this.getStats = this.getStats.bind(this);
  }

  componentDidMount() {
    this.getStats();
  }

  getStats() {
    axios.get('/api/v1/ln_stats.json').then(function (response) {
      return response.data;
    }).then(function (stats) {
      this.setState({
        stats: stats
      });
    }.bind(this)).catch(function (error) {
      console.error(error);
    });
  }

  render() {
    if (this.props.penalties) {
      return(
        <span>
          { this.state.stats &&
            <span>
            (
              <NumberFormat value={ this.state.stats.penalty_total } displayType={'text'} decimalScale={3} fixedDecimalScale={true} />&nbsp;
              BTC total in { this.state.stats.penalty_count } transactions)
            </span>
          }
        </span>
      );
    } else {
      return(
        <span>
          { this.state.stats &&
            <span>
              <NumberFormat value={ this.state.stats.sweep_total } displayType={'text'} decimalScale={3} fixedDecimalScale={true} />&nbsp;
              BTC total in { this.state.stats.sweep_count } regular sweep transactions not shown.
            </span>
          }
        </span>
      );

    }
  }
}
export default LightningStats
