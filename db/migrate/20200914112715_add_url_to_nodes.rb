# frozen_string_literal: true

class AddUrlToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :link, :string
    add_column :nodes, :link_text, :string

    if Rails.env.production?
      Node.find(155).update version_extra: '', link: 'https://blog.bitmex.com/bitcoin-satellite/', link_text: '📡'
    end
  end
end
