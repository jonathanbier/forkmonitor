class SafariSubscription < ApplicationRecord
  # Send push notifications to everyone
  def self.blast(tag, subject, body)
    SafariSubscription.all.each do |s|
      Rpush::Apns::Notification.create(
        app: Rpush::Apns::App.find_by_name("Fork Monitor"),
        device_token: s.device_token,
        alert: {
          title: subject,
          body: body
        },
        url_args: []
      )
    end

  end
end
