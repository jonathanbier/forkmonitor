import React from 'react';
import { Link } from "react-router-dom";
import PropTypes from 'prop-types';

import {
    UncontrolledAlert
} from 'reactstrap';

class AlertStale extends React.Component {
  render() {
    const branchCount = this.props.candidate.n_children;
    return(
      <UncontrolledAlert color="warning">
        There are { branchCount } blocks at height { this.props.candidate.height }
        . <Link to={ `/stale/${ this.props.candidate.height }` }>More info</Link>
      </UncontrolledAlert>
    );
  }
}

AlertStale.propTypes = {
  currentHeight: PropTypes.number.isRequired
}

export default AlertStale
