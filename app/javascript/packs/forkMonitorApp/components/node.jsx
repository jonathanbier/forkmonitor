import React from 'react';

import Moment from 'react-moment';
import NumberFormat from 'react-number-format';

import {
    Badge,
    BreadcrumbItem,
    Breadcrumb
} from 'reactstrap';

Number.prototype.pad = function(size) {
  var s = String(this);
  while (s.length < (size || 2)) {s = "0" + s;}
  return s;
}

class Node extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      node: props.node
    };
  }

  render() {
    const version = this.state.node.version.pad(8).split( /(?=(?:..)*$)/ ).map(Number)
    return(
      <li>
        <b>
          {this.state.node.name}
          <span className="node-version">
            { " " }{version[0]}.{version[1]}.{version[2]}
            {version[3] > 0 &&
              <span>.{version[3]}</span>
            }
          </span>
          {this.state.node.unreachable_since!=null &&
            <span> <Badge color="warning">Offline</Badge></span>
          }
          {this.state.node.ibd &&
            <span> <Badge color="info">Syncing</Badge></span>
          }
        </b>
      </li>
    )
  }
}
export default Node
