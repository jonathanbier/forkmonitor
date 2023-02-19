class DropRpush < ActiveRecord::Migration[6.1]
  def up
    drop_table :rpush_apps
    drop_table :rpush_feedback
    drop_table :rpush_notifications
  end
end
