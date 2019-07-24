import React from 'react';

import axios from 'axios';

import {
    Container,
    TabPane,
    UncontrolledAlert
} from 'reactstrap';

import Chaintip from './chaintip';
import NodesWithoutTip from './nodesWithoutTip';
import NodeName from './nodeName';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class Nodes extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      coin: props.match.params.coin,
      chaintips: [],
      nodesWithoutTip: [],
      invalid_blocks: []
    };

    this.getChaintips = this.getChaintips.bind(this);
    this.getNodes = this.getNodes.bind(this);
    this.getInvalidBlocks = this.getInvalidBlocks.bind(this);

    function toByteArray(hexString) {
      var result = [];
      for (var i = 0; i < hexString.length; i += 2) {
        result.push(parseInt(hexString.substr(i, 2), 16));
      }
      return new Uint8Array(result);
    }

    var vapidPublicKey = toByteArray(process.env['VAPID_PUBLIC_KEY']);

    function checkNotifs(obj){
      if (!("Notification" in window)) {
        return;
      }
      // Check whether notification permissions have already been granted
      if (Notification.permission === "granted") {
        getKeys();
        return;
      }
      // TODO: move this to button
      // Ask the user for permission
      if (Notification.permission !== 'denied') {
        Notification.requestPermission(function (permission) {
          // If the user accepts, let's create a notification
          if (permission === "granted") {
            getKeys();
          }
        });
      }
   }

   function getKeys(){
     navigator.serviceWorker.register('/serviceworker.js', {scope: './'})
       .then(function(registration) {
         return registration.pushManager.getSubscription()
           .then(function(subscription) {
             if (subscription) {
               return subscription;
             }
             return registration.pushManager.subscribe({
               userVisibleOnly: true,
               applicationServerKey: vapidPublicKey
             }).then(function(subscription) {
               axios.post('/api/v1/subscriptions', {
                 subscription: subscription
               }).then(function (response) {
                 return response.data;
               }).catch(function (error) {
                 console.error(error);
               });
             });
           });
       });
     }

     checkNotifs()
  }

  componentDidMount() {
    this.getChaintips(this.state.coin);
    this.getNodes(this.state.coin);
    this.getInvalidBlocks(this.state.coin);
  }

  componentWillReceiveProps(nextProps) {
    const currentCoin = this.state && this.state.coin;
    const nextCoin = nextProps.match.params.coin;

    if (currentCoin !== nextCoin) {
      this.setState({
        nodesWithoutTip: [],
        chaintips: [],
        invalid_blocks: []
      });
      this.getChaintips(nextProps.match.params.coin);
      this.getNodes(nextProps.match.params.coin);
      this.getInvalidBlocks(nextProps.match.params.coin);
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

   getInvalidBlocks(coin) {
     axios.get('/api/v1/invalid_blocks?coin=' + coin).then(function (response) {
       return response.data;
     }).then(function (invalid_blocks) {
       this.setState({
         invalid_blocks: invalid_blocks
       });
    }.bind(this)).catch(function (error) {
      console.error(error);
    });
  }

  render() {
      return(
        <TabPane align="left" >
          <br />
          { (this.state && this.state.invalid_blocks || []).map(function (invalid_block) {
            return (
                <UncontrolledAlert color="danger" key={invalid_block.id}>
                  <NodeName node={invalid_block.node} /> considers
                  block { invalid_block.block.hash } at height { invalid_block.block.height } invalid.
                  This block was mined by { invalid_block.block.pool ? invalid_block.block.pool : "an unknown pool" }.
                  { invalid_block.block.first_seen_by &&
                    <span>
                      {} It was first seen and accepted as valid by <NodeName node={invalid_block.block.first_seen_by} />.
                    </span>
                  }

                </UncontrolledAlert>
            )
          }.bind(this))}
          <Container>
              {(this.state && this.state.chaintips || []).map(function (chaintip, index) {
                return (<Chaintip
                  key={ chaintip.id }
                  coin={ this.state.coin }
                  chaintip={ chaintip }
                  nodes={ chaintip.nodes }
                  index={ index }
                  last={ index != this.state.chaintips.length - 1 }
                  invalid_blocks={ this.state.invalid_blocks }
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
export default Nodes
