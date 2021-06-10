# frozen_string_literal: true

class AddRawToTransactions < ActiveRecord::Migration[5.2]
  def up
    add_column :transactions, :raw, :binary

    Block.joins(:transactions).order(:height).uniq.each do |block|
      puts "Re-fetch transactions for block #{block.coin} #{block.height} #{block.block_hash}..."
      block.transactions.delete_all
      block.fetch_transactions!
    end
  end

  def down
    remove_column :transactions, :raw
  end
end
