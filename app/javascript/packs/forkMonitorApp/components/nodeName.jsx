
import React from 'react';

class NodeName extends React.Component {
  // Convert country code to flag emoji
  countryCodeToFlag(countryCode) {
    if (!countryCode || countryCode.length !== 2) {
      return '';
    }
    const codePoints = countryCode
      .toUpperCase()
      .split('')
      .map(char => 127397 + char.charCodeAt());
    return String.fromCodePoint(...codePoints);
  }

  render() {
    const flag = this.countryCodeToFlag(this.props.node.country);
    return(
      <span>
        {flag && <span title={this.props.node.country}>{flag}&nbsp;</span>}
        {this.props.node.name_with_version}
      </span>
    )
  }
}
export default NodeName
