# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationMailer do
  it 'can suppress application email without suppressing exception email' do
    allow(Rails.env).to receive(:production?).and_return(true)
    mailer_class = Class.new(described_class) do
      def notification
        mail(to: 'user@example.com', body: 'Body')
      end
    end
    stub_const('NotificationMailer', mailer_class)

    message = NotificationMailer.notification.message

    expect(message.perform_deliveries).to be(false)
    expect(ActionMailer::Base.perform_deliveries).to be(true)
  end

  it 'is the parent mailer for Devise email' do
    expect(Devise.parent_mailer).to eq('ApplicationMailer')
  end
end
