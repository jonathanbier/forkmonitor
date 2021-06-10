# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'info@forkmonitor.info'
  layout 'mailer'
end
