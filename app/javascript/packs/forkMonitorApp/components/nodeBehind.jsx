import React from 'react';

import { Badge } from 'reactstrap';

class NodeBehind extends React.Component {
  render() {
    let chaintipHeight = this.props.chaintip ? this.props.chaintip.block.height : null;
    let nodeHeight = this.props.node ? this.props.node.height : null;
    let delta = chaintipHeight && nodeHeight && chaintipHeight - nodeHeight;

    if (delta < 1) {
      return(<span />)
    }

    return(
      <span> <Badge color={ delta <= 1 ? "info" : delta <= 5 ? "warning" : "danger" }>
          { delta + " " }
          { this.props.verbose &&
            <span>{ delta == 1 ? "block " : "blocks " }</span>
          }
          behind
        </Badge>
      </span>
    )
  }
}
export default NodeBehind
