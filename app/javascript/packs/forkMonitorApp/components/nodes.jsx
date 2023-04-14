import React from 'react';

import PropTypes from 'prop-types';

import axios from 'axios';

import {
    Container,
    TabPane,
    UncontrolledAlert
} from 'reactstrap';

import Chaintip from './chaintip';
import NodesWithoutTip from './nodesWithoutTip';
import NodeName from './nodeName';
import Alerts from './alerts';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class Nodes extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      chaintips: [],
      nodesWithoutTip: [],
      currentHeight: null,
      fresh: false
    };
  }

  componentDidMount() {
    this.getChaintips();
    this.getNodes();
  }

  componentDidUpdate() {
    if (this.state.fresh) {
      this.getChaintips();
      this.getNodes();
      this.setState({
          fresh: false
      })
    }
  }

  getChaintips() {
    axios.get('/api/v1/chaintips').then(function (response) {
      return response.data;
    }).then(function (chaintips) {
      this.setState({
        chaintips: chaintips,
        currentHeight: Math.max.apply(Math, chaintips.map(function(c) { return c.block.height }))
      });
      }.bind(this)).catch(function (error) {
        console.error(error);
      });
   }

  getNodes() {
    axios.get('/api/v1/nodes/coin/btc').then(function (response) {
      return response.data;
    }).then(function (nodes) {
      var unique = (arrArg) => arrArg.filter((elem, pos, arr) => arr.findIndex(x => x && elem && x.hash === elem.hash) == pos)

      this.setState({
        nodesWithoutTip: nodes.filter(node => node.ibd || node.height == null || node.unreachable_since ),
      });

      }.bind(this)).catch(function (error) {
        console.error(error);
      });
   }

  render() {
      return(
        <TabPane align="left" >
          <Alerts currentHeight={ this.state.currentHeight } />
          <Container>
              {(this.state && this.state.chaintips || []).map(function (chaintip, index) {
                return (<Chaintip
                  key={ chaintip.id }
                  chaintip={ chaintip }
                  nodes={ chaintip.nodes }
                  index={ index }
                  last={ index != this.state.chaintips.length - 1 }
                  cableApp={ this.props.cableApp }
                />)
              }.bind(this))}
              { this.state.nodesWithoutTip.length > 0 &&
                <NodesWithoutTip
                  nodes={ this.state.nodesWithoutTip }
                  cableApp={ this.props.cableApp }
                />
              }
          </Container>

        </TabPane>
      );
  }
}


Nodes.propTypes = {
}

export default Nodes
