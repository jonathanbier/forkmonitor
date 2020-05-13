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
      coin: props.match.params.coin,
      chaintips: [],
      nodesWithoutTip: [],
      fresh: false
    };
  }

  componentDidMount() {
    this.getChaintips(this.state.coin);
    this.getNodes(this.state.coin);
  }

  static getDerivedStateFromProps(props, state) {
    const currentCoin = state.coin;
    const nextCoin = props.match.params.coin;

    if (currentCoin !== nextCoin) {
      state.coin = props.match.params.coin;
      state.nodesWithoutTip = [];
      state.chaintips = [];
      state.fresh = true;
    }

    return state;
  }

  componentDidUpdate() {
    if (this.state.fresh) {
      this.getChaintips(this.state.coin);
      this.getNodes(this.state.coin);
      this.setState({
          fresh: false
      })
    }
  }

  getChaintips(coin) {
    axios.get('/api/v1/chaintips/' + coin).then(function (response) {
      return response.data;
    }).then(function (chaintips) {
      this.setState({
        chaintips: chaintips
      });
      }.bind(this)).catch(function (error) {
        console.error(error);
      });
   }

  getNodes(coin) {
    axios.get('/api/v1/nodes/coin/' + coin).then(function (response) {
      return response.data;
    }).then(function (nodes) {
      var unique = (arrArg) => arrArg.filter((elem, pos, arr) => arr.findIndex(x => x && elem && x.hash === elem.hash) == pos)

      this.setState({
        coin: coin,
        nodesWithoutTip: nodes.filter(node => node.ibd || node.height == null || node.unreachable_since ),
      });

      }.bind(this)).catch(function (error) {
        console.error(error);
      });
   }

  render() {
      return(
        <TabPane align="left" >
          <Alerts coin={ this.state.coin } />
          <Container>
              {(this.state && this.state.chaintips || []).map(function (chaintip, index) {
                return (<Chaintip
                  key={ chaintip.id }
                  coin={ this.props.match.params.coin }
                  chaintip={ chaintip }
                  nodes={ chaintip.nodes }
                  index={ index }
                  last={ index != this.state.chaintips.length - 1 }
                  cableApp={ this.props.cableApp }
                />)
              }.bind(this))}
              { this.state.nodesWithoutTip.length > 0 &&
                <NodesWithoutTip coin={ this.state.coin } nodes={ this.state.nodesWithoutTip } />
              }
          </Container>

        </TabPane>
      );
  }
}


Nodes.propTypes = {
}

export default Nodes
