import React from 'react';
import PropTypes from 'prop-types';

import ImageBlockstream from '../assets/images/blockstream.png'
import ImageBtcCom from '../assets/images/btc.png'
import ImageOneML from '../assets/images/1ml.png'
import ImageMempool from '../assets/images/mempool.png'

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
    } else if (this.props.oneML) {
      url = "https://1ml.com/channel/" + this.props.channelId
      image = ImageOneML
    } else if (this.props.mempool) {
      url = "https://mempool.space/lightning/channel/" + this.props.channelId
      image = ImageMempool
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
