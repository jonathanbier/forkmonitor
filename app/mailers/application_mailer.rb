# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  after_action :disable_production_delivery

  default from: 'info@forkmonitor.info'
  layout 'mailer'

  private

  # Keep ActionMailer::Base enabled so exception_notification can still report
  # production failures, while suppressing application-generated email.
  def disable_production_delivery
    mail.perform_deliveries = false if Rails.env.production?
  end
end
