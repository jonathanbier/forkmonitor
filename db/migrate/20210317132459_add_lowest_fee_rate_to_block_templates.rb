class AddLowestFeeRateToBlockTemplates < ActiveRecord::Migration[5.2]
  def change
    add_column :block_templates, :lowest_fee_rate, :integer
    add_column :blocks, :lowest_template_fee_rate, :integer
  end
end
