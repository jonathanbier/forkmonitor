# frozen_string_literal: true

class AddNotifiedAtToLags < ActiveRecord::Migration[5.2]
  def change
    add_column :lags, :notified_at, :datetime
  end
end
