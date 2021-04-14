import React from 'react';

import axios from 'axios';
import PropTypes from 'prop-types';

import NodeName from './nodeName';
import AlertSoftfork from './alertSoftfork';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class SoftforkAlerts extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      fresh: true
    };
  }

  componentDidMount() {
    this.getSoftforks(this.props.coin);
  }

  static getDerivedStateFromProps(props, state) {
    const currentCoin = state.coin;
    const nextCoin = props.coin;

    if (currentCoin !== nextCoin) {
      state.coin = props.coin;
      state.fresh = true;
    }

    return state;
  }

  componentDidUpdate() {
    if (this.state.fresh) {
      this.getSoftforks(this.state.coin);
      this.setState({
          fresh: false
      });
    }

  }

   getSoftforks(coin) {
     axios.get(`/api/v1/softforks/${ coin }.json`).then(function (response) {
       return response.data;
     }).then(function (softforks) {
       this.setState({
         softforks: softforks,
       });
    }.bind(this)).catch(function (error) {
      console.error(error);
    });
  }

  render() {
    return(
      <div>
        { (this.state && this.state.softforks || []).filter(
          c => this.props.currentHeight - c.height < 2096 * 4
        ).map(function (softfork) {
          return (<AlertSoftfork softfork={ softfork }  coin={ this.state.coin } key={ softfork.id }/>)
        }.bind(this))}
      </div>
    );
  }
}

SoftforkAlerts.propTypes = {
  currentHeight: PropTypes.number.isRequired
}

export default SoftforkAlerts
