import React from 'react';
import { Link } from "react-router-dom";
import PropTypes from 'prop-types';

import {
    UncontrolledAlert
} from 'reactstrap';

class AlertSoftfork extends React.Component {
  render() {
    return(
      <UncontrolledAlert color="warning">
        status became { this.props.softfork.status } at height { this.props.softfork.height }&nbsp;
        { this.props.softfork.fork_type } { this.props.softfork.name } softfork
        status became { this.props.softfork.status } at height { this.props.softfork.height }
        according to { this.props.softfork.node_name }
      </UncontrolledAlert>
    );
  }
}

export default AlertSoftfork
