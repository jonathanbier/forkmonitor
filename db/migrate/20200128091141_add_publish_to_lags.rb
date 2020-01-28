class AddPublishToLags < ActiveRecord::Migration[5.2]
  def change
    add_column :lags, :publish, :boolean, default: true, null:  false
  end
end
