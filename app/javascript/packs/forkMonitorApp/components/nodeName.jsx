import React from 'react';

Number.prototype.pad = function(size) {
  var s = String(this);
  while (s.length < (size || 2)) {s = "0" + s;}
  return s;
}

class NodeName extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      node: props.node
    };
  }

  render() {
    const version = this.state.node.version.pad(8).split( /(?=(?:..)*$)/ ).map(Number)
    return(
      <span>
        {this.state.node.name}
        <span className="node-version">
          { " " }{version[0]}.{version[1]}.{version[2]}
          {version[3] > 0 &&
            <span>.{version[3]}</span>
          }
        </span>
      </span>
    )
  }
}
export default NodeName
