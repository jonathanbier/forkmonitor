import React from 'react';
import PropTypes from 'prop-types';

import ImageBlockstream from '../assets/images/blockstream.png'
import ImageBtcCom from '../assets/images/btc.png'
import ImageOneML from '../assets/images/1ml.png'

class Explorer extends React.Component {
  render() {
    let url;
    let image;
    const coin = this.props.coin;
    if (this.props.blockstream) {
      var rootUrl = "https://blockstream.info/";
      if (coin == "btc") {
      } else if (coin == "tbtc") {
        rootUrl += "testnet/"
      } else {
        return null;
      }
      if (this.props.tx) {
        url = rootUrl + "tx/" + this.props.tx
      } else {
        url = rootUrl + "block/" + this.props.block
      }
      image = ImageBlockstream
    } else if (this.props.btcCom) {
      var rootUrl = "https://btc.com/";
      if (coin == "btc") {
      } else if (coin == "tbtc") {
        return null;
      } else {
        return null;
      }
      if (this.props.tx) {
        url = rootUrl + this.props.tx
      } else {
        url = rootUrl + this.props.block
      }
      image = ImageBtcCom
    } else if (this.props.oneML) {
      url = "https://1ml.com/channel/" + this.props.channelId
      image = ImageOneML
    } else {
      console.error("Must specify explorer")
    }
    return(
      <a href={url} target="_blank"><img src={ image }  height="18pt"/></a>
    );
  }
}

Explorer.propTypes = {
  coin: PropTypes.string.isRequired,
  tx: PropTypes.string,
  channelId: PropTypes.string
}

export default Explorer
