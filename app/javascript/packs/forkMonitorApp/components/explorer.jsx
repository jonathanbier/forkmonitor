import React from 'react';
import PropTypes from 'prop-types';

import ImageBlockstream from '../assets/images/blockstream.png'

class Explorer extends React.Component {
  render() {
    let url;
    let image;
    if (this.props.blockstream) {
      var rootUrl = "https://blockstream.info/";
      if (this.props.tx) {
        url = rootUrl + "tx/" + this.props.tx
      } else {
        url = rootUrl + "block/" + this.props.block
      }
      image = ImageBlockstream
    } else {
      console.error("Must specify explorer")
    }
    return(
      <a href={url} target="_blank"><img src={ image }  height="18pt"/></a>
    );
  }
}

Explorer.propTypes = {
  tx: PropTypes.string,
  channelId: PropTypes.string
}

export default Explorer
