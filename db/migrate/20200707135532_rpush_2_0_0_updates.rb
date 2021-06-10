# frozen_string_literal: true

class Rpush200Updates < ActiveRecord::VERSION::MAJOR >= 5 ? ActiveRecord::Migration[5.0] : ActiveRecord::Migration
  module Rpush
    class App < ActiveRecord::Base
      self.table_name = 'rpush_apps'
    end

    class Notification < ActiveRecord::Base
      self.table_name = 'rpush_notifications'
    end
  end

  def self.update_type(model, from, to)
    model.where(type: from).update_all(type: to)
  end

  def self.up
    add_column :rpush_notifications, :processing, :boolean, null: false, default: false
    add_column :rpush_notifications, :priority, :integer, null: true

    if ActiveRecord.version >= Gem::Version.new('5.1')
      if index_name_exists?(:rpush_notifications, :index_rpush_notifications_multi)
        remove_index :rpush_notifications, name: :index_rpush_notifications_multi
      end
    elsif index_name_exists?(:rpush_notifications, :index_rpush_notifications_multi, true)
      remove_index :rpush_notifications, name: :index_rpush_notifications_multi
    end

    add_index :rpush_notifications, %i[delivered failed], name: 'index_rpush_notifications_multi',
                                                          where: 'NOT delivered AND NOT failed'

    rename_column :rpush_feedback, :app, :app_id

    if postgresql?
      execute('ALTER TABLE rpush_feedback ALTER COLUMN app_id TYPE integer USING (trim(app_id)::integer)')
    else
      change_column :rpush_feedback, :app_id, :integer
    end

    %i[Apns Gcm Wpns Adm].each do |service|
      update_type(Rpush200Updates::Rpush::App, "Rpush::#{service}::App", "Rpush::Client::ActiveRecord::#{service}::App")
      update_type(Rpush200Updates::Rpush::Notification, "Rpush::#{service}::Notification",
                  "Rpush::Client::ActiveRecord::#{service}::Notification")
    end
  end

  def self.down
    %i[Apns Gcm Wpns Adm].each do |service|
      update_type(Rpush200Updates::Rpush::App, "Rpush::Client::ActiveRecord::#{service}::App", "Rpush::#{service}::App")
      update_type(Rpush200Updates::Rpush::Notification, "Rpush::Client::ActiveRecord::#{service}::Notification",
                  "Rpush::#{service}::Notification")
    end

    change_column :rpush_feedback, :app_id, :string
    rename_column :rpush_feedback, :app_id, :app

    if ActiveRecord.version >= Gem::Version.new('5.1')
      if index_name_exists?(:rpush_notifications, :index_rpush_notifications_multi)
        remove_index :rpush_notifications, name: :index_rpush_notifications_multi
      end
    elsif index_name_exists?(:rpush_notifications, :index_rpush_notifications_multi, true)
      remove_index :rpush_notifications, name: :index_rpush_notifications_multi
    end

    add_index :rpush_notifications, %i[app_id delivered failed deliver_after],
              name: 'index_rpush_notifications_multi'

    remove_column :rpush_notifications, :priority
    remove_column :rpush_notifications, :processing
  end

  def self.adapter_name
    env = defined?(Rails) && Rails.env ? Rails.env : 'development'
    ActiveRecord::Base.configurations[env].transform_keys(&:to_sym)[:adapter]
  end

  def self.postgresql?
    adapter_name =~ /postgresql|postgis/
  end
end
