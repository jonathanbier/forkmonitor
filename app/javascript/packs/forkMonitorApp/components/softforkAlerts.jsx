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
    this.getSoftforks();
  }

  componentDidUpdate() {
    if (this.state.fresh) {
      this.getSoftforks();
      this.setState({
          fresh: false
      });
    }

  }

   getSoftforks() {
     axios.get(`/api/v1/softforks.json`).then(function (response) {
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
          return (<AlertSoftfork softfork={ softfork } key={ softfork.id }/>)
        }.bind(this))}
      </div>
    );
  }
}

SoftforkAlerts.propTypes = {
  currentHeight: PropTypes.number.isRequired
}

export default SoftforkAlerts
