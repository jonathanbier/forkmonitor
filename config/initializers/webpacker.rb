Webpacker::Compiler.env['GOOGLE_ANALYTICS'] = ENV['GOOGLE_ANALYTICS']
Webpacker::Compiler.env['VAPID_PUBLIC_KEY'] = Base64.urlsafe_decode64(ENV['VAPID_PUBLIC_KEY']).bytes.pack('C*').unpack1('H*')
