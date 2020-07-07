class SafariController < ApplicationController
  layout false

  def log
    head :no_content
  end

  def package
    send_file "public/pushPackage.zip", :type => 'application/zip',
                :disposition => 'attachment',
                :filename => "pushPackage.zip"
  end

  def registrations
    SafariSubscription.find_or_create_by(device_token: params[:device_token])
    head :no_content
  end
end
