class DropSafariSubscriptions < ActiveRecord::Migration[6.1]
  def up
    drop_table :safari_subscriptions
  end
end
