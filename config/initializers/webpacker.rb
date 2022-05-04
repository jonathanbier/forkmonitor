# frozen_string_literal: true

Webpacker::Compiler.env['GOOGLE_ANALYTICS'] = ENV.fetch('GOOGLE_ANALYTICS', nil)
Webpacker::Compiler.env['VAPID_PUBLIC_KEY'] = ENV.fetch('VAPID_PUBLIC_KEY', nil)
