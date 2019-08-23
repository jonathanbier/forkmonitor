#encoding: UTF-8
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fork Monitor - Inflated #{ @coin.upcase } blocks"
    xml.description "Blocks with extra inflation"
    xml.link root_url

    @inflated_blocks.each do |inflated_block|
      xml.item do
        xml.title "#{ inflated_block.actual_inflation -  inflated_block.max_inflation } BTC extra inflation between height #{ inflated_block.comparison_block.height } and #{ inflated_block.block.height }."
        xml.description "Unexpected #{ inflated_block.actual_inflation -  inflated_block.max_inflation } BTC extra inflation between height #{ inflated_block.comparison_block.height } and #{ inflated_block.block.height }. This block was first seen and accepted as valid by #{ inflated_block.block.first_seen_by.name_with_version }."
        xml.pubDate inflated_block.created_at.to_s(:rfc822)
        xml.link api_v1_inflated_block_url(inflated_block)
        xml.guid api_v1_inflated_block_url(inflated_block)
      end
    end
  end
end
