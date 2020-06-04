import React from 'react';

import axios from 'axios';

import {
    Container,
    TabPane
} from 'reactstrap';

import RSSFeeds from './RSSFeeds';

axios.defaults.headers.post['Content-Type'] = 'application/json'

/**
 * urlBase64ToUint8Array
 *
 * @param {string} base64String a public vavid key
 */
function urlBase64ToUint8Array(base64String) {
    var padding = '='.repeat((4 - base64String.length % 4) % 4);
    var base64 = (base64String + padding)
        .replace(/\-/g, '+')
        .replace(/_/g, '/');

    var rawData = window.atob(base64);
    var outputArray = new Uint8Array(rawData.length);

    for (var i = 0; i < rawData.length; ++i) {
        outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
}

class NotificationsPage extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      webpush: null,
      vapidPublicKey: process.env['VAPID_PUBLIC_KEY']
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
    navigator.serviceWorker.register(process.env.NODE_ENV == 'production' ? '/assets/serviceworker-4712d5ce5f6340d63e10db26507ae3a44d29fb8629d66adbb6a7e0696301f2e0.js' : '/assets/serviceworker.js', {scope: './assets/'})
    .then(function(registration) {
      return registration.pushManager.getSubscription()
        .then(function(subscription) {
          if (subscription) {
            return subscription;
          }
          return registration.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: urlBase64ToUint8Array(applicationServerKey)
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
    }).catch(console.error);
  }

  componentDidMount() {
    this.checkNotifs();
  }

  render() {
      return(
        <TabPane align="left" >
          <br />
          <Container>
            <h2>Browser push notifications</h2>
            <p>
              We currently send browser push notifications for invalid blocks (all coins),
              stale candidates (all coins except testnet) and unexpected extra inflation (Bitcoin and testnet).
              Tested with Chrome. Safari is currently not supported.
            </p>
            { this.state && this.state.webpush == false &&
              <p>Browser push notification permission denied</p>
            }
            { this.state && this.state.webpush == true &&
              <p>Browser push notifications enabled. You can close this page.</p>
            }
            <br />
            <RSSFeeds />
          </Container>
        </TabPane>
      );
  }
}
export default NotificationsPage
