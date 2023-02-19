# frozen_string_literal: true

class Subscription < ApplicationRecord
  class << self
    # Send push notifications to everyone
    def blast(tag, subject, body)
      Subscription.all.find_each do |s|
        WebPush.payload_send(
          endpoint: s.endpoint,
          message: "#{tag}|#{subject}|#{body}",
          p256dh: s.p256dh,
          auth: s.auth,
          ttl: 60 * 60,
          vapid: {
            subject: "mailto:#{ENV.fetch('VAPID_CONTACT_EMAIL', nil)}",
            public_key: ENV.fetch('VAPID_PUBLIC_KEY', nil),
            private_key: ENV.fetch('VAPID_PRIVATE_KEY', nil)
          }
        )
      rescue WebPush::Unauthorized, WebPush::ExpiredSubscription
        s.destroy
      end
    end
  end
end
