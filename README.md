# Fork Monitor [![Build Status](https://travis-ci.com/BitMEXResearch/forkmonitor.svg?branch=master)](https://travis-ci.com/BitMEXResearch/forkmonitor) [![Coverage Status](https://coveralls.io/repos/github/BitMEXResearch/forkmonitor/badge.svg?branch=master)](https://coveralls.io/github/BitMEXResearch/forkmonitor?branch=master)

## Tools

To get a list of chaintips for all nodes run:

```rb
rake blocks:get_chaintips
```

```
Node 1: Bitcoin Core 0.17.99:
HEIGHT | BRANCHLEN | STATUS        | HASH
-------|-----------|---------------|-----------------------------------------------------------------
572319 | 0         | active        | 0000000000000000002671de2c0d7966398eef6c36e5c23706e36f2b6ba34633
525890 | 1         | valid-headers | 0000000000000000003d068ec400b1042b8d1ed867cf3c380b64ca074c6d12c7
```

## Push notifications

Generate a `VAPID_PUBLIC_KEY` and `VAPID_PRIVATEY_KEY` for push notifications:

```rb
npm install -g web-push
web-push generate-vapid-keys
```

Also provide a contact email via `VAPID_CONTACT_EMAIL=`.

To test notifications, open the site in Chrome and give permission, and then:

```rb
@subscription = Subscription.last
Webpush.payload_send(endpoint: @subscription.endpoint, message: "tag|title|body", p256dh: @subscription.p256dh, auth: @subscription.auth, vapid: { subject: "mailto:" + ENV['VAPID_CONTACT_EMAIL'], public_key: ENV['VAPID_PUBLIC_KEY'] , private_key: ENV['VAPID_PRIVATE_KEY'] }, ttl: 60 * 60)
```
