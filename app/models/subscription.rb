# frozen_string_literal: true

class Subscription < ApplicationRecord
  # Send push notifications to everyone
  def self.blast(tag, subject, body)
    Subscription.all.find_each do |s|
      Webpush.payload_send(
        endpoint: s.endpoint,
        message: "#{tag}|#{subject}|#{body}",
        p256dh: s.p256dh,
        auth: s.auth,
        ttl: 60 * 60,
        vapid: {
          subject: "mailto:#{ENV['VAPID_CONTACT_EMAIL']}",
          public_key: ENV['VAPID_PUBLIC_KEY'],
          private_key: ENV['VAPID_PRIVATE_KEY']
        }
      )
    rescue Webpush::Unauthorized
      s.destroy
    rescue Webpush::ExpiredSubscription
      s.destroy
    end

    SafariSubscription.blast(tag, subject, body)
  end
end
