# frozen_string_literal: true

class AddVersionBitsToBlocks < ActiveRecord::Migration[5.2]
  def up
    add_column :blocks, :version, :int
    node = Node.where(coin: 'BTC').reorder(version: :desc).first
    if node.present?
      block = node.block
      loop do
        block_header = node.client.getblockheader(block.block_hash)
        block.update version: block_header['version']
        break unless block = block.parent
      end
    end
  end

  def down
    add_column :blocks, :version_bits
  end
end
