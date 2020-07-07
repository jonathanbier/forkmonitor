class Subscription < ApplicationRecord
  # Send push notifications to everyone
  def self.blast(tag, subject, body)
    Subscription.all.each do |s|
      begin
        Webpush.payload_send(endpoint: s.endpoint, message: "#{tag}|#{subject}|#{body}", p256dh: s.p256dh, auth: s.auth, vapid: { subject: "mailto:" + ENV['VAPID_CONTACT_EMAIL'], public_key: ENV['VAPID_PUBLIC_KEY'] , private_key: ENV['VAPID_PRIVATE_KEY'] }, ttl: 60 * 60)
      rescue Webpush::Unauthorized
        s.destroy
      rescue Webpush::ExpiredSubscription
        s.destroy
      end
    end

    SafariSubscription.blast(tag, subject, body)

  end
end
