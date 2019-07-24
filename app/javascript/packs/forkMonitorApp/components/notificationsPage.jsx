import React from 'react';

import axios from 'axios';

import {
    Container,
    TabPane
} from 'reactstrap';

axios.defaults.headers.post['Content-Type'] = 'application/json'

class NotificationsPage extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      webpush: null,
      vapidPublicKey: toByteArray(process.env['VAPID_PUBLIC_KEY'])
    };

    function toByteArray(hexString) {
      var result = [];
      for (var i = 0; i < hexString.length; i += 2) {
        result.push(parseInt(hexString.substr(i, 2), 16));
      }
      return new Uint8Array(result);
    }
  }

  checkNotifs() {
    if (!("Notification" in window)) {
      return;
    }
    // Check whether notification permissions have already been granted
    if (Notification.permission === "granted") {
      this.setState({
        webpush: true
      });
      this.getKeys();
      return;
    }
    // Ask the user for permission
    if (Notification.permission !== 'denied') {
      var self = this;
      Notification.requestPermission(function (permission) {
        // If the user accepts, let's create a notification
        if (permission === "granted") {
          self.setState({
            webpush: true
          });
          self.getKeys();
        } else if (permission === "denied") {
          self.setState({
            webpush: false
          });
        }
      });
    } else {
      this.setState({
        webpush: false
      });
    }
 }

  getKeys() {
    var applicationServerKey = this.state.vapidPublicKey;
    navigator.serviceWorker.register('/serviceworker.js', {scope: './'})
    .then(function(registration) {
      return registration.pushManager.getSubscription()
        .then(function(subscription) {
          if (subscription) {
            return subscription;
          }
          return registration.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: applicationServerKey
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

  componentDidMount() {
    this.checkNotifs();
  }

  componentWillReceiveProps(nextProps) {
  }

  render() {
      return(
        <TabPane align="left" >
          <br />
          <Container>
            <h2>Browser push notifications</h2>
            { this.state && this.state.webpush == false &&
              <p>Browser push notification permission denied</p>
            }
            { this.state && this.state.webpush == true &&
              <p>Browser push notifications enabled. You can close this page.</p>
            }
          </Container>
        </TabPane>
      );
  }
}
export default NotificationsPage
