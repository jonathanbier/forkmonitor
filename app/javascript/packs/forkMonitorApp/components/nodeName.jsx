import React from 'react';

class NodeName extends React.Component {
  render() {
    return(
      <span>
        {this.props.node.name_with_version}
      </span>
    )
  }
}
export default NodeName
