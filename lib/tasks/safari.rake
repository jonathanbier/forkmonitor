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
      authenticationToken: ENV.fetch('SAFARI_AUTH_TOKEN', nil),
      webServiceURL: 'https://forkmonitor.info/push'
    }
    iconset_path = 'app/assets/images/safari_iconset'
    certificate = 'tmp/production.p12'
    intermediate_cert = 'tmp/AppleWWDRCAG4.cer'
    package = PushPackage.new(website_params, iconset_path, certificate, ENV.fetch('CERT_PWD', nil),
                              intermediate_cert)
    package.save('public/pushPackage.zip')
  end

  desc 'Register app'
  task register_app: [:environment] do
    app = Rpush::Apns2::App.new
    app.name = 'Fork Monitor'
    app.certificate = File.read('certs/production.pem')
    app.environment = 'production'
    app.password = ENV.fetch('CERT_PWD', nil)
    app.connections = 1
    app.save!
  end
end
