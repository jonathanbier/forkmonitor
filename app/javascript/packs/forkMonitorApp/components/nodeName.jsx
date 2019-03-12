import React from 'react';

Number.prototype.pad = function(size) {
  var s = String(this);
  while (s.length < (size || 2)) {s = "0" + s;}
  return s;
}

class NodeName extends React.Component {
  render() {
    var versionString = ""
    if (this.props.node.version) {
      const version = this.props.node.version.pad(8).split( /(?=(?:..)*$)/ ).map(Number);
      versionString =  ` ${version[0]}.${version[1]}.${version[2]}`;
      if (versionString[3] > 0) {
        versionString += `.${version[3]}`;
      }
    }

    return(
      <span>
        {this.props.node.name}
        <span className="node-version">
          {versionString}
        </span>
      </span>
    )
  }
}
export default NodeName
