import React from 'react';

class NodeBehind extends React.Component {
  render() {
    let chaintipHeight = this.props.chaintip ? this.props.chaintip.block.height : null;
    let nodeHeight = this.props.node ? this.props.node.height : null;
    let delta = chaintipHeight && nodeHeight && chaintipHeight - nodeHeight;

    if (delta <= 0) {
      return(<span />)
    }

    return(
      <span> (
      { delta }
      { delta == 1 ? " block " : " blocks " }
      behind)
      </span>
    )
  }
}
export default NodeBehind
