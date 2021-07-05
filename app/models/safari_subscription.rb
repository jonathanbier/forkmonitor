# frozen_string_literal: true

class SafariSubscription < ApplicationRecord
  # Send push message to this device
  def notify(subject, body)
    Rpush::Apns2::Notification.create(
      app: Rpush::Apns::App.find_by(name: 'Fork Monitor'),
      device_token: device_token,
      alert: {
        title: subject,
        body: body
      },
      url_args: []
    )
  end

  class << self
    # Send push notifications to everyone
    def blast(subject, body)
      SafariSubscription.all.find_each do |s|
        s.notify(subject, body)
      end
    end
  end
end
