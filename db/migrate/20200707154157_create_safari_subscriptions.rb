class CreateSafariSubscriptions < ActiveRecord::Migration[5.2]
  def change
    create_table :safari_subscriptions do |t|
      t.string :device_token, unique: true

      t.timestamps
    end
  end
end
