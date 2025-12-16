import React from 'react';
import PropTypes from 'prop-types';

import ImageMempool from '../assets/images/mempool.png'

class Explorer extends React.Component {
  render() {
    let url;
    let image;
    if (this.props.mempool) {
      const rootUrl = "https://mempool.space/";
      if (this.props.tx) {
        url = rootUrl + "tx/" + this.props.tx
      } else if (this.props.block) {
        url = rootUrl + "block/" + this.props.block
      } else if (this.props.channelId) {
        url = rootUrl + "lightning/channel/" + this.props.channelId
      }
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
  block: PropTypes.string,
  channelId: PropTypes.string,
  coin: PropTypes.string,
  mempool: PropTypes.bool
}

export default Explorer
