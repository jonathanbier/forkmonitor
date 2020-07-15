import React from 'react';

import ImageBlockstream from '../assets/images/blockstream.png'
import ImageBtcCom from '../assets/images/btc.png'
import ImageOneML from '../assets/images/1ml.png'

class Explorer extends React.Component {
  render() {
    let url;
    let image;
    if (this.props.blockstream) {
      if (this.props.tx) {
        url = "https://blockstream.info/tx/" + this.props.tx
      } else {
        url = "https://blockstream.info/block/" + this.props.block
      }
      image = ImageBlockstream
    } else if (this.props.btcCom) {
      if (this.props.tx) {
        url = "https://btc.com/" + this.props.tx
      } else {
        url = "https://btc.com/" + this.props.block
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
export default Explorer
