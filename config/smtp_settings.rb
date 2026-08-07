# frozen_string_literal: true

module SmtpSettings
  TRUE_VALUES = %w[1 true yes on].freeze

  def self.from_env(env)
    {
      user_name: env.fetch('SMTP_USERNAME'),
      password: env.fetch('SMTP_PASSWORD'),
      domain: env.fetch('SMTP_DOMAIN', 'forkmonitor.info'),
      address: env.fetch('SMTP_ADDRESS'),
      port: Integer(env.fetch('SMTP_PORT', 587)),
      authentication: env.fetch('SMTP_AUTHENTICATION', 'plain').to_sym,
      enable_starttls_auto: TRUE_VALUES.include?(env.fetch('SMTP_ENABLE_STARTTLS_AUTO', 'true').downcase)
    }
  end
end
