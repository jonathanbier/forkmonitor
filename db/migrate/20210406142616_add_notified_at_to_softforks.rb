# frozen_string_literal: true

class AddNotifiedAtToSoftforks < ActiveRecord::Migration[5.2]
  def change
    add_column :softforks, :notified_at, :datetime
  end
end
