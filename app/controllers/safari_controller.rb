# frozen_string_literal: true

class SafariController < ApplicationController
  layout false

  def log
    render json: { message: 'ok' }, status: 200
  end

  def package
    send_file 'public/pushPackage.zip', type: 'application/zip',
                                        disposition: 'attachment',
                                        filename: 'pushPackage.zip'
  end

  def registrations
    SafariSubscription.find_or_create_by(device_token: params[:device_token])
    render json: { message: 'ok' }, status: 200
  end

  def deregister
    SafariSubscription.where(device_token: params[:device_token]).destroy_all
    render json: { message: 'ok' }, status: 200
  end
end
