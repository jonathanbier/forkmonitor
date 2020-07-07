class SafariController < ApplicationController
  layout false

  def v1_log
    head :no_content
  end

  def v2_log
    head :no_content
  end

  def v2_package
    send_file "public/pushPackage.zip", :type => 'application/zip',
                :disposition => 'attachment',
                :filename => "pushPackage.zip"
  end

  def v2_registrations
    SafariSubscription.find_or_create_by(device_token: params[:device_token])
    head :no_content
  end
end
