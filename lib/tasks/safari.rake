require 'push_package'
namespace 'safari' do :env
  desc "Generate Push Package"
  task :generate_push_package => [:environment] do
    website_params = {
      websiteName: "Fork Monitor",
      websitePushID: "web.info.forkmonitor",
      allowedDomains: ["https://forkmonitor.info"],
      urlFormatString: "https://forkmonitor.info",
      authenticationToken: ENV["SAFARI_AUTH_TOKEN"],
      webServiceURL: "https://forkmonitor.info/push"
    }
    iconset_path = 'app/assets/images/safari_iconset'
    certificate = 'tmp/forkmonitor.p12'
    intermediate_cert = 'tmp/AppleWWDRCA.cer'
    package = PushPackage.new(website_params, iconset_path, certificate, ENV['CERT_PWD'], intermediate_cert)
    package.save('public/pushPackage.zip')
  end
end
