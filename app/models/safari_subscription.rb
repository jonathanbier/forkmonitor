# frozen_string_literal: true

class SafariSubscription < ApplicationRecord
  # Send push notifications to everyone
  def self.blast(_tag, subject, body)
    SafariSubscription.all.find_each do |s|
      Rpush::Apns::Notification.create(
        app: Rpush::Apns::App.find_by_name('Fork Monitor'),
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
