import React from 'react';

class NodeBehindBlocks extends React.Component {
  render() {
    let chaintipHeight = this.props.chaintip ? this.props.chaintip.block.height : null;
    let nodeHeight = this.props.node ? this.props.node.height : null;
    let delta = chaintipHeight && nodeHeight && chaintipHeight - nodeHeight;

    if (delta <= 0) {
      return(<span />)
    }

    if (delta <= 4) {
      let blocks = " ";
      for (let i = 0; i < delta; i++) {
        blocks += "□ ";
      }
      return(<span>{ blocks } </span>)
    }

    return(<span> □… □ </span>)
  }
}
export default NodeBehindBlocks
