import React from 'react';
import PropTypes from 'prop-types';
import Moment from 'react-moment';

const TimestampField = ({ source, record = {} }) => <Moment format="YYYY-MM-DD HH:mm" parse="X">{record[source]}</Moment>;

TimestampField.propTypes = {
    label: PropTypes.string,
    record: PropTypes.object,
    source: PropTypes.string.isRequired,
};

export default TimestampField;
