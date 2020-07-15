import React from 'react';
import { Link } from "react-router-dom";
import PropTypes from 'prop-types';

import {
    UncontrolledAlert
} from 'reactstrap';

class AlertStale extends React.Component {
  render() {
    return(
      <UncontrolledAlert color="warning">
        There { this.props.currentHeight > this.props.candidate.height ? "were" : "are" } { this.props.candidate.blocks.length } blocks at height { this.props.candidate.height }
        . <Link to={ `/stale/${ this.props.candidate.coin }/${ this.props.candidate.height }` }>More info</Link>
      </UncontrolledAlert>
    );
  }
}

AlertStale.propTypes = {
  currentHeight: PropTypes.number.isRequired
}

export default AlertStale
