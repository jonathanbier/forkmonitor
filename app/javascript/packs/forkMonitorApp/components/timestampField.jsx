import React from 'react';
import PropTypes from 'prop-types';
import get from 'lodash/get';
import Moment from 'react-moment';
import 'moment-timezone'

const TimestampField = ({ source, record = {} }) => {
  const value = get(record, source);
  if (value) {
    return (
      <Moment format="YYYY-MM-DD HH:mm" tz="UTC" parse="X">{value}</Moment>
    )
  } else {
    return (<span />)
  }
}

TimestampField.propTypes = {
    label: PropTypes.string,
    record: PropTypes.object,
    source: PropTypes.string.isRequired,
};

export default TimestampField;
