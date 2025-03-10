import React from 'react';
import PropTypes from 'prop-types';

import ImageBlockstream from '../assets/images/blockstream.png'
import ImageBtcCom from '../assets/images/btc.png'

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
    } else if (this.props.btcCom) {
      var rootUrl = "https://btc.com/";
      if (this.props.tx) {
        url = rootUrl + this.props.tx
      } else {
        url = rootUrl + this.props.block
      }
      image = ImageBtcCom
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
