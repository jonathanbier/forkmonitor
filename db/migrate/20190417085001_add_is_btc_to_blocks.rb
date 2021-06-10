# frozen_string_literal: true

class AddIsBtcToBlocks < ActiveRecord::Migration[5.2]
  def up
    add_column :blocks, :is_btc, :boolean, default: false

    # node = Node.bitcoin_by_version.first
    # if node.present?
    #   block = node.block
    #   while block.parent.present? do
    #     block.update is_btc: true
    #     block = block.parent
    #   end
    # end

    add_index :blocks, :is_btc
  end

  def down
    remove_column :blocks, :is_btc
  end
end
