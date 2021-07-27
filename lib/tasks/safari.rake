# frozen_string_literal: true

require 'push_package'
namespace 'safari' do
  desc 'Generate Push Package'
  task generate_push_package: [:environment] do
    website_params = {
      websiteName: 'Fork Monitor',
      websitePushID: 'web.info.forkmonitor',
      allowedDomains: ['https://forkmonitor.info'],
      urlFormatString: 'https://forkmonitor.info',
      authenticationToken: ENV['SAFARI_AUTH_TOKEN'],
      webServiceURL: 'https://forkmonitor.info/push'
    }
    iconset_path = 'app/assets/images/safari_iconset'
    certificate = 'tmp/production.p12'
    intermediate_cert = 'tmp/AppleWWDRCAG3.cer'
    package = PushPackage.new(website_params, iconset_path, certificate, ENV['CERT_PWD'],
                              intermediate_cert)
    package.save('public/pushPackage.zip')
  end

  desc 'Register app'
  task register_app: [:environment] do
    app = Rpush::Apns2::App.new
    app.name = 'Fork Monitor'
    app.certificate = File.read('certs/production.pem')
    app.environment = 'production'
    app.password = ENV['CERT_PWD']
    app.connections = 1
    app.save!
  end
end
