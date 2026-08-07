# frozen_string_literal: true

require 'spec_helper'
require_relative '../../config/smtp_settings'

RSpec.describe SmtpSettings do
  describe '.from_env' do
    it 'builds provider-neutral SMTP settings' do
      settings = described_class.from_env(
        'SMTP_ADDRESS' => 'smtp.fastmail.com',
        'SMTP_PORT' => '587',
        'SMTP_USERNAME' => 'user@example.com',
        'SMTP_PASSWORD' => 'app-password',
        'SMTP_DOMAIN' => 'example.com',
        'SMTP_AUTHENTICATION' => 'plain',
        'SMTP_ENABLE_STARTTLS_AUTO' => 'true'
      )

      expect(settings).to eq(
        address: 'smtp.fastmail.com',
        port: 587,
        user_name: 'user@example.com',
        password: 'app-password',
        domain: 'example.com',
        authentication: :plain,
        enable_starttls_auto: true
      )
    end

    it 'supports disabling STARTTLS auto-negotiation' do
      settings = described_class.from_env(
        'SMTP_ADDRESS' => 'smtp.example.com',
        'SMTP_USERNAME' => 'user',
        'SMTP_PASSWORD' => 'password',
        'SMTP_ENABLE_STARTTLS_AUTO' => 'false'
      )

      expect(settings[:enable_starttls_auto]).to be(false)
    end

    it 'rejects an incomplete configuration' do
      expect do
        described_class.from_env('SMTP_ADDRESS' => 'smtp.fastmail.com')
      end.to raise_error(KeyError, /SMTP_USERNAME/)
    end
  end
end
